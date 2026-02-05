# 发布与自动更新（Sparkle + GitHub Releases）

本项目使用 Sparkle 做应用内“检查更新”，并用 GitHub Releases 托管 `SnapPath.zip` 和 `appcast.xml`。

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

1. 合并到 `main`
2. 打 tag（必须是 `vX.Y.Z` 形式）：
   ```bash
   git tag v1.2.3
   git push origin v1.2.3
   ```
3. 等 GitHub Actions 完成：
   - 自动构建 Universal `SnapPath.app`
   - 打包 `SnapPath.zip`
   - 生成并上传 `appcast.xml`
   - 创建/更新 GitHub Release（包含上述两个资产）

## 常见问题

- 如果 `SUPublicEDKey` 还是占位符或 Secret 未配置，CI 会在生成 appcast 阶段失败，避免发布不可用更新。
- 丢失 Sparkle 私钥会导致你无法给后续更新签名（老版本也就无法信任新更新），务必备份。

