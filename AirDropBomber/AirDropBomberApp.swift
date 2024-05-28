import SwiftUI

@main
struct AirDropBomberApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    checkNewVersions()
                    
                    // Очистить каталог tmp
                    for url in (try? FileManager.default.contentsOfDirectory(at: FileManager.default.temporaryDirectory, includingPropertiesForKeys: nil)) ?? [] {
                        try? FileManager.default.removeItem(at: url)
                    }
                    
                    // Проверить наличие рут прав, то есть джейлбрейка
                        do {
                        try FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: "/var/mobile"), includingPropertiesForKeys: nil)
                    } catch {
                        UIApplication.shared.alert(body: "The application requires root rights and jailbreak to operate: \(error)", withButton: false)
                    }
                }
        }
    }
    
    // Проверить есть ли обновления на GitHub
    func checkNewVersions() {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, let url = URL(string: "https://api.github.com/repos/Parad1st/AirDropBomder/releases/latest") {
            let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
                guard let data = data else { return }
                
                if let json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                    if (json["tag_name"] as? String)?.compare(version, options: .numeric) == .orderedDescending {
                        UIApplication.shared.confirmAlert(title: "Update available", body: "Update is available, do you want to visit download page?", onOK: {
                            UIApplication.shared.open(URL(string: "https://github.comParad1st/AirDropBomder/releases/latest")!)
                        }, noCancel: false)
                    }
                }
            }
            task.resume()
        }
    }
}

func remLog(_ objs: Any...) {
    for obj in objs {
        let args: [CVarArg] = [ String(describing: obj) ]
        withVaList(args) { RLogv("%@", $0) }
    }
}
