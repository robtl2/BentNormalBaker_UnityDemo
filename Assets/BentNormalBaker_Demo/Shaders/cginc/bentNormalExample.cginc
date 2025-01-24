
#ifndef BENT_NROMAL_CGINCLUD
#define BENT_NROMAL_CGINCLUD

#define TEST_IRR_Y00  float3(2.0029711723327637, 2.165761947631836, 2.6534738540649414)
#define TEST_IRR_Y1_1  float3(-0.16298185288906097, -0.22775554656982422, -0.27095112204551697)
#define TEST_IRR_Y10  float3(-0.8857064247131348, -1.0363900661468506, -1.3874431848526)
#define TEST_IRR_Y11  float3(0.2668744623661041, 0.19551032781600952, 0.12910377979278564)
#define TEST_IRR_Y2_2  float3(0.1393672227859497, 0.13479149341583252, 0.12897151708602905)
#define TEST_IRR_Y2_1  float3(0.12585772573947906, 0.20881570875644684, 0.28985944390296936)
#define TEST_IRR_Y20  float3(-0.046638764441013336, 0.026730341836810112, 0.15353433787822723)
#define TEST_IRR_Y21  float3(-0.3169068992137909, -0.2965661585330963, -0.2996731996536255)
#define TEST_IRR_Y22  float3(0.03668118640780449, 0.03721760958433151, 0.043264709413051605)

#define SH_COEFFS_Y00   0.282095
#define SH_COEFFS_Y1_1  0.345494
#define SH_COEFFS_Y10   0.488603
#define SH_COEFFS_Y11   -0.345494
#define SH_COEFFS_Y2_2  0.386274
#define SH_COEFFS_Y2_1  0.772548
#define SH_COEFFS_Y20   0.315392
#define SH_COEFFS_Y21   -0.772548
#define SH_COEFFS_Y22   -0.386274

float3 sample_irradiance(float3 dir, float intensity){
    // 这里测试用的系数是blender那边坐标系积分出来的，所以采样前先换到unity这边的axis
    dir = dir.xzy;
    dir.xz = -dir.xz;

    // 没优化算法，应该组几个matrix来批量dot
    float y00 = SH_COEFFS_Y00;
    float y1_1 = SH_COEFFS_Y1_1 * dir.y;
    float y10 = SH_COEFFS_Y10 * dir.z;
    float y11 = SH_COEFFS_Y11 * dir.x;
    float y2_2 = SH_COEFFS_Y2_2 * dir.x * dir.y;
    float y2_1 = SH_COEFFS_Y2_1 * dir.y * dir.z;
    float y20 = SH_COEFFS_Y20 * (dir.z * dir.z * 3 - 1) * 0.5;
    float y21 = SH_COEFFS_Y21 * dir.x * dir.z;
    float y22 = SH_COEFFS_Y22 * (dir.x * dir.x - dir.y * dir.y) * 0.5;

    float3 color = TEST_IRR_Y00 * y00;
    color += TEST_IRR_Y1_1 * y1_1;
    color += TEST_IRR_Y10 * y10;
    color += TEST_IRR_Y11 * y11;
    color += TEST_IRR_Y2_2 * y2_2;
    color += TEST_IRR_Y2_1 * y2_1;
    color += TEST_IRR_Y20 * y20;
    color += TEST_IRR_Y21 * y21;
    color += TEST_IRR_Y22 * y22;

    return color*intensity;
}

float remap(float min_from, float max_from, float min_to, float max_to, float value){
    float normalized = (value - min_from) / (max_from - min_from);
    return min_to + normalized * (max_to - min_to);
}

void transform_dir_half(float4x4 mat, float3 dir, out float3 Out){
    float3x3 mat3 = (float3x3)mat;
    Out = mul(mat3, dir);
}

void tbn_to_world_half(float3 T, float3 B, float3 N, float3 dir, out float3 Out){
    Out = T*dir.x + B*dir.y + N*dir.z;
}

void decode_color_half(float4 col, out float3 SH1, out float SH0){
    float3 dir = col.xyz;
    dir = dir*2 -1;
    SH1 = dir;
    SH0 = col.a;
}

void decode_uv_half(float4 uv1, float4 uv2, out float3 SH1, out float SH0){
    float3 dir = float3(uv1.xy, uv2.x);
    SH1 = dir;
    SH0 = uv2.y;
}

void sample_occ_half(float3 dir, float sh0, float3 sh1, out float OCC, out float SH){
    float3 a = dir * float3(SH_COEFFS_Y1_1, SH_COEFFS_Y10, SH_COEFFS_Y1_1);
    float b = dot(a, sh1);
    float sh = sh0*SH_COEFFS_Y00 + b;
    sh *= 6.28319;
    sh = saturate(sh);
    OCC = pow(sh, 2);
    SH = sh;
}

void self_occ_half(float3 dir, float sh0, float3 sh1, float min_from, float max_from, out float OCC){
    float occ;
    float sh;
    sample_occ_half(dir, sh0, sh1, occ, sh);

    OCC = saturate(remap(min_from, max_from, 0, 1, occ));
}


void sss_lighting_half(float3 L, float3 N, float3 color, float intensity, 
                        float offset, float sh0, float3 sh1, 
                        float3 bent_normal, float AO, out float3 Color){

    float BNoL = dot(bent_normal, L);
    BNoL = max(0, BNoL);
    float occ;
    self_occ_half(L, sh0, sh1, 0, offset, occ);
    float blurry_lighting = lerp(occ, BNoL, 0.75625);

    float NoL = dot(N, L);
    NoL = max(0, NoL);
    float ao = remap(0, offset, 0.2, 1, AO);

    float hard_lighting = NoL * ao;

    float r = lerp(hard_lighting, blurry_lighting, color.r);
    float g = lerp(hard_lighting, blurry_lighting, color.g);
    float b = lerp(hard_lighting, blurry_lighting, color.b);

    float3 rgb = float3(r, g, b);

    rgb = lerp(float3(hard_lighting, hard_lighting, hard_lighting),rgb, intensity);

    Color = rgb/3.14159;
}



void sss_irradiance_half(float3 color, float offset, float intensity, 
                        float ao, float3 N, float3 bent_normal, out float3 Color){
    float intensity_hard = remap(0, offset, 0, 1, ao);
    float intensity_soft = remap(0, offset, 0.4, 1, ao);

    float3 irr_hard = sample_irradiance(N, intensity_hard);
    float3 irr_soft = sample_irradiance(bent_normal, intensity_soft);

    float r = lerp(irr_hard.r, irr_soft.r, color.r);
    float g = lerp(irr_hard.g, irr_soft.g, color.g);
    float b = lerp(irr_hard.b, irr_soft.b, color.b);

    float3 rgb = float3(r, g, b);

    Color = lerp(irr_hard, rgb, intensity);
}

void reflection_occ_half(float3 R, float sh0, float3 sh1, out float OCC){
    float occ;
    self_occ_half(R, sh0, sh1, 0.17, 0.4, occ);
    OCC = occ; 
}

void rim_occ_half(float3 L, float sh0, float3 sh1, out float OCC){
    float occ;
    self_occ_half(L, sh0, sh1, 0.2, 0.3, occ);
    OCC = occ;
}







#endif