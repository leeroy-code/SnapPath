import SwiftUI

struct AboutView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 20) {
            // App Icon
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 80, height: 80)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.accentColor)
            }
            
            VStack(spacing: 8) {
                Text(Constants.appName)
                    .font(.system(size: 24, weight: .bold))
                
                Text("\("about.version".localized) \(version) (\(build))")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                Text("about.copyright".localized)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .padding(.horizontal, 40)
            
            VStack(spacing: 12) {
                Button(action: {
                    if let url = URL(string: "https://github.com/leeroy-code/SnapPath") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "link")
                        Text("about.github".localized)
                    }
                    .frame(width: 160)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Text("about.acknowledgements".localized)
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                    .onTapGesture {
                        // 可以打开一个致谢窗口或网页
                    }
            }
        }
        .padding(.vertical, 30)
        .frame(width: 320, height: 380)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
