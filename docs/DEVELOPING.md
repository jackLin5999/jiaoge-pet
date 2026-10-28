# 开发与维护说明

这份文件是给维护者/贡献者看的，普通用户请直接看 [README](../README.md) 或 [INSTALL.md](../INSTALL.md)。

## 文件结构

- `Sources/main.swift`：造型、绘制、动画、气泡、剪贴板面板、控制器
- `Sources/Features.swift`：大模型配置与请求、聊天输入框、设置窗口、剪贴板条目/面板、OCR
- `Resources/crowns/`：段位皇冠素材（`<大段位>_<1-4>.png`，1=IV、4=I；大师以上单张）
- `build.sh` / `run.sh` / `release.sh`：编译、编译并启动、打发布包
- `INSTALL.md`：给使用者的安装说明（也会生成一份纯文本塞进发布 zip）

## 改造型

造型是直接按参考图的像素坐标画的：`Banana` 里每个部件的点都写成参考图（560×750）上的坐标，
画的时候用 `artToView` 统一缩放，所以改大小只要动 `CELL`，几何数字不用重算。

- `Banana.body` / `stem` / `leftArm` / `rightArm` / `feet` / `spots`：各部件轮廓
- `rgb(...)`：配色全部取自参考图，**按 Display P3 标注**——参考图就是 P3 色彩空间，写成 sRGB 会明显偏淡
- `PetController.lines` / `stemLines` / `eyeLines` …：各部位随机说的台词
- `makePose()`：所有动画曲线（呼吸、眨眼、跳、挥手、压扁、拖拽），想加动作在这里加
- `hitAreaContains`：可点击区域

## 编译与签名

```bash
./build.sh                 # 本机架构，快
ARCHS=universal ./build.sh # 尝试 arm64 + x86_64 通用包
```

- 用 Command Line Tools 的 `swiftc` 直接编译，不需要完整 Xcode
- **通用二进制需要完整 Xcode**：命令行工具里没有 x86_64 的 Swift 兼容库，交叉编译会失败，
  `ARCHS=universal` 会自动退回本机架构
- 签名优先用钥匙串里的 `JiaoGe Local Signing` 自签名证书，没有则退回 ad-hoc
- 自签名证书的生成要点：必须带 `extendedKeyUsage=critical,codeSigning`，
  否则 `security find-identity -p codesigning` 不认；openssl 导出的 p12 用 `security import`
  会报 MAC verification failed，改成分别导入 cert.pem / key.pem 就正常

### 关于屏幕录制权限

macOS 的屏幕录制授权**绑定在代码签名上**：

- 用 ad-hoc 签名时，每次重新编译签名都变，授权立刻失效（设置界面仍显示开关是开的，容易误判）
- 用固定证书签名后，重新编译不影响授权
- 授权后**必须重启 app** 才生效

## 离线识别是怎么做的

Vision 的 `recognitionLanguages` 对结果影响极大：列表里混入中文，韩文会被认成汉字、西里尔字母直接失效；
不指定语言时又会跟着系统语言走，中文识别反而变差。所以按文字类型分轮跑：

```
中日英 → 韩 → 阿拉伯 → 泰 → 印地 → 自动
```

第一轮达标（字数 ≥ 8 且置信度 ≥ 0.7）就直接返回，常见情况只跑一次。

## 调试与自检

```bash
# 完整自检：素材、配置目录、大模型配置、屏幕录制、快捷键、剪贴板
./build/JiaoGe.app/Contents/MacOS/JiaoGe --self-test

# 只查截图权限（注意：从终端跑会继承终端的权限，GUI 里未必一样）
./build/JiaoGe.app/Contents/MacOS/JiaoGe --check-capture

# 命令行问一句，不启动界面
JIAOGE_API_URL=… JIAOGE_API_KEY=… ./build/JiaoGe.app/Contents/MacOS/JiaoGe --ask "你好"
```

app 每次启动会把真实的屏幕录制权限写一行到 `/tmp/jiaoge-perm.log`，
这是判断 GUI 实例权限最可靠的方式。
