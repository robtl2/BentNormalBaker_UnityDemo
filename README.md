# BentNormalBaker UnityDemo

blender插件BentNormalBaker的UnityDemo, 使用的是2022.3.2t13版本,
只要支持URP的Unity版本应该都可以使用

## 使用方法

1. 使用Unity打开该项目
2. 打开Assets/BentNormalBaker_Demo/SampleScene场景
3. 导入从blender导出的fbx或glb文件
4. 给导入的Mesh添加Assets/BentNormalBaker_Demo/Materials/DebugBentNormalBaker.mat材质
5. 检验效果是否符合预期


## 注意事项

- DebugBentNormalBaker材质中的use TBN space与Channel选项需要与blender插件BentNormalBaker中的设置一致

## 在其它项目中使用

- 要在其它项目中使用这些材质效果需要对Untiy ShaderGraph和Shader Lab有一定的了解。
- 所有光照计算都可以在Assets/BentNormalBaker_Demo/Shaders目录中找到，可将需要的功能块复制到其它项目的Shader中。

