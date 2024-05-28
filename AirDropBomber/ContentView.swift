import SwiftUI
import Photos

struct ContentView: View {
    // Кря
    @Environment(\.openURL) var openURL
    
    // Какой человек выбран
    @State var selectedPeople: [TDKSFNode: Bool] = [:]
    
    // Контроллео
    @StateObject var bombController = BomberController(sharedURL: Bundle.main.url(forResource: "Trollface", withExtension: "png")!, rechargeDuration: 0.5)
    @State var rechargeDuration: Double = 0.5
    @State var showingImagePicker: Bool = false
    
    @State var totalAirDrops: Int = 0
    
    /// Своя картинка
    @State var imageURL: URL?
    
    private var gridItemLayout = [GridItem(.adaptive(minimum: 75, maximum: 100))]
    
    var body: some View {
        NavigationView {
            Group {
                if bombController.people.count == 0 { // Если нет челов
                    VStack {
                        ProgressView()
                        Text("Searching for devices...")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                } else {
                    VStack {
                        ScrollView {
                            LazyVGrid(columns: gridItemLayout, spacing: 8) {
                                ForEach(bombController.people.sorted(by: { a, b in a.displayName ?? "" < b.displayName ?? "" }), id: \.node) { p in
                                    PersonView(person: p, selected: $selectedPeople[p.node])
                                        .environmentObject(bombController)
                                }
                            }
                        }
                        .padding()
                        VStack {
                            if bombController.isRunning { Text("Sent AirDrop: \(totalAirDrops)") }
                            HStack { // delay
                                Image(systemName: "timer")
                                Slider(value: $rechargeDuration, in: 0...3.5)
                                Text(String(format: "%.1fs", rechargeDuration))
                            }
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                if imageURL == nil {
                                    showPicker()
                                } else {
                                    imageURL = nil
                                }
                            }) {
                                Text(imageURL == nil ? "Select custom image" : imageURL!.lastPathComponent)
                                    .padding(16)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(uiColor14: UIColor.secondarySystemFill    ))
                                    .cornerRadius(8)
                                    .sheet(isPresented: $showingImagePicker) {
                                        ImagePickerView(imageURL: $imageURL)
                                    }
                            }
                            
                            Button(action: {
                                toggleTrollButtonTapped()
                            }) {
                                Text(!bombController.isRunning ? "Start bombig" : "Stop bombing")
                                    .padding(16)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("AirDropBomber")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        openURL(URL(string: "https://github.com/Parad1st/AirDropBomber")!)
                    }) {
                        Image("github")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                    }
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        openURL(URL(string: "https://youtube.com/@Parad1st")!)
                    }) {
                        Image(systemName: "heart.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            // Начать поиск
            bombController.startBrowser()
        }
        .onChange(of: rechargeDuration) { newValue in
            bombController.rechargeDuration = newValue
        }
        
    }
    
    // при необходимости показывает диалоговое окно запроса конфиденциальности
    func showPicker() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                // показать выборщик, если авторизован
                showingImagePicker = status == .authorized
            }
        }
    }
    
    func toggleTrollButtonTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred() // mmm
        
        guard selectedPeople.values.filter({ $0 == true }).count > 0 else {
            UIApplication.shared.alert(title: "No people selected", body: "Select users.")
            return
        }
        
        if !bombController.isRunning {
            UIApplication.shared.confirmAlert(title: "\(UIDevice.current.name)", body: "This is the current name of this device and is the name people will see when receiving an AirDrop. Are you sure you want to continue?", onOK: {
                if let imageURL = imageURL {
                    bombController.sharedURL = imageURL
                }
                bombController.startBombing(shouldTrollHandler: { person in
                    return selectedPeople[person.node] ?? false //  только если выбран
                }, eventHandler: { event in
                    switch event {
                    case .operationEvent(let event1):
                        if event1 == .canceled || event1 == .finished || event1 == .blocked {
                            totalAirDrops += 1
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                    case .cancelled:
                        totalAirDrops += 1
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                }) // начать бомбить
                bombController.isRunning.toggle()
            }, noCancel: false)
        } else {
            bombController.stopBombings()
            bombController.isRunning.toggle()
        }
    }
    
    struct PersonView: View {
        @State var person: BomberController.Person
        @Binding var selected: Bool?
        @EnvironmentObject var bombController: BomberController
        
        var body: some View {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if selected == nil { selected = false }
                selected?.toggle()
                remLog("selected", selected!)
            }) {
                VStack {
                    ZStack {
                        Image((selected ?? false) ? "TrolledPerson" : "NonTrolledPerson")
                    }
                    Text(person.displayName ?? "Unknown")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .foregroundColor(.init(uiColor14: .label))
                }
            }
            .disabled(bombController.isRunning)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
//Пишу это чисто для себя!
// Короче я тут чета напутал, маленькая буква это бомб большая это Бомбер
//Если код поломал то проверь это
//---
//Если вы читаете это и ничего не поняли, то забейте я просто тупой
//Кста подпишитесь на ютуб пж
//сяб :3
