# 发布与自动更新（Sparkle + GitHub Releases）

本项目使用 Sparkle 做应用内“检查更新”，并用 GitHub Releases 托管 `SnapPath.zip` 和 `appcast.xml`。

## 版本号规则

- Git tag 必须是 `vX.Y.Z`（例如 `v1.3.3`）。
- CI 会在打 tag 时使用 tag 里的版本号覆盖构建参数（见 `.github/workflows/build.yml` 中的 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`）。
- 建议在本地也把 Xcode 项目版本号更新到同一个 `X.Y.Z`，方便本地运行/关于页面/排查问题时一致。

## 一次性准备

1. **生成 Sparkle Ed25519 密钥**
   - `Info.plist` 里的 `SUPublicEDKey` 必须是公钥（base64）。
   - 私钥（base64）必须保存好（建议放密码管理器），同时写入 GitHub Actions Secret。

2. **设置 GitHub Actions Secret**
   - Name：`SPARKLE_ED25519_PRIVATE_KEY`
   - Value：你的 Sparkle Ed25519 私钥（base64，一行）

3. **开启 workflow 写权限**
   - GitHub Repo → Settings → Actions → General → Workflow permissions
   - 选择 `Read and write permissions`

## 发版流程

### 1) 更新版本号（推荐）

在 Xcode 中打开项目 → Target `SnapPath` → Build Settings：

- `MARKETING_VERSION`：更新为 `X.Y.Z`
- `CURRENT_PROJECT_VERSION`：更新为 `X.Y.Z`（本项目也允许用同一套版本号）

然后提交一次（建议单独 commit）：

```bash
git add SnapPath.xcodeproj/project.pbxproj
git commit -m "chore: bump version to X.Y.Z"
```

### 2) 合并到 `main`

走正常 PR 合并流程即可（确保 main 上是你要发布的代码）。

### 3) 打 tag 并推送

打 tag（必须是 `vX.Y.Z` 形式）：

   ```bash
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

### 4) 等 GitHub Actions 完成

等待 CI 完成后，会自动：
   - 自动构建 Universal `SnapPath.app`
   - 打包 `SnapPath.zip`
   - 生成并上传 `appcast.xml`
   - 创建/更新 GitHub Release（包含上述两个资产）

> 注意：仓库根目录的 `appcast.xml` 是占位文件，实际发布用的 `appcast.xml` 由 GitHub Actions 在打 tag 时生成并上传到 Release 资产里。

## 常见问题

- 如果 `SUPublicEDKey` 还是占位符或 Secret 未配置，CI 会在生成 appcast 阶段失败，避免发布不可用更新。
- 丢失 Sparkle 私钥会导致你无法给后续更新签名（老版本也就无法信任新更新），务必备份。
