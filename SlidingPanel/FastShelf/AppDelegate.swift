//
//  AppDelegate.swift
//  SlidingPanel
//
//  Created by Andrey Barsuk on 12/10/24.
//


import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate {
    var panel: NSPanel!
    var timer: Timer?
    var tableView: NSTableView!
    var storedItems: [URL] = []
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        // Получаем размеры экрана и меню бара
        let screenHeight = NSScreen.main?.frame.height ?? 800
        let screenWidth = NSScreen.main?.frame.width ?? 1200
        let menuBarHeight = NSScreen.main?.frame.minY ?? 0
        
        let panelHeight = screenHeight - abs(menuBarHeight) - 40
        panel = NSPanel(
            contentRect: NSRect(x: screenWidth - 200, y: 0, width: 200, height: panelHeight),
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.isFloatingPanel = true
        panel.backgroundColor = .windowBackgroundColor
        panel.alphaValue = 0.95
        panel.isOpaque = false
        panel.hasShadow = true
        
        // Создаем контейнер для контента
        let contentView = NSView(frame: panel.contentRect(forFrameRect: panel.frame))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        let topPadding = panelHeight - 40
        
        // Создаем заголовок
        let label = NSTextField(frame: NSRect(x: 10, y: topPadding, width: panel.frame.width - 90, height: 30))
        label.stringValue = "FastShelf"
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.alignment = .left
        label.font = NSFont.boldSystemFont(ofSize: 16)
        contentView.addSubview(label)
        
        // Создаем кнопку Clear
        let clearButton = NSButton(frame: NSRect(x: panel.frame.width - 70, y: topPadding, width: 60, height: 30))
        clearButton.title = "Clear"
        clearButton.bezelStyle = NSButton.BezelStyle.rounded
        clearButton.target = self
        clearButton.action = #selector(clearButtonClicked)
        contentView.addSubview(clearButton)
        
        // Создаем TableView
        let scrollView = NSScrollView(frame: NSRect(x: 10, y: 10, width: 180, height: topPadding - 20))
        tableView = NSTableView(frame: scrollView.bounds)
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("files"))
        column.title = "Files"
        column.width = 170
        tableView.addTableColumn(column)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        tableView.registerForDraggedTypes([.fileURL])
        tableView.rowHeight = 24
        tableView.intercellSpacing = NSSize(width: 0, height: 4)
        tableView.allowsMultipleSelection = true
        
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        
        contentView.addSubview(scrollView)
        
        panel.contentView = contentView
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkMousePosition()
        }
        
        // Добавляем таймер для проверки существования файлов каждые 5 минут
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.validateStoredItems()
        }
        
        // Загружаем сохраненные файлы
        loadStoredItems()
        
        tableView.target = self
        tableView.doubleAction = #selector(tableViewDoubleClick(_:))
        
        // В методе applicationDidFinishLaunching добавим регистрацию для исходящего drag&drop
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
    }
    
    @objc private func clearButtonClicked() {
        storedItems.removeAll()
        tableView.reloadData()
        saveStoredItems()
    }
    
    private func validateStoredItems() {
        let validItems = storedItems.filter { url in
            return (try? url.checkResourceIsReachable()) == true
        }
        
        if validItems.count != storedItems.count {
            storedItems = validItems
            tableView.reloadData()
            saveStoredItems()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }
    
    func checkMousePosition() {
        let mouseLocation = NSEvent.mouseLocation
        let screenWidth = NSScreen.main?.frame.width ?? 1200
        
        if mouseLocation.x > screenWidth - 5 {
            showPanel()
        } else if mouseLocation.x < screenWidth - 205 {
            hidePanel()
        }
    }
    
    func showPanel() {
        if !panel.isVisible {
            let screenWidth = NSScreen.main?.frame.width ?? 1200
            panel.setFrameOrigin(NSPoint(x: screenWidth - 200, y: 0))
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                panel.animator().alphaValue = 0.95
                panel.orderFront(nil)
            }
        }
    }
    
    func hidePanel() {
        if panel.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                panel.animator().alphaValue = 0
            } completionHandler: {
                self.panel.orderOut(nil)
            }
        }
    }
    
    // MARK: - TableView DataSource
    func numberOfRows(in tableView: NSTableView) -> Int {
        return storedItems.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("FileCellView")
        var cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView
        
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = identifier
            
            // Создаем ImageView для иконки
            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(imageView)
            cell?.imageView = imageView
            
            // Создаем TextField для имени файла
            let textField = NSTextField()
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.isEditable = false
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.lineBreakMode = .byTruncatingTail
            cell?.addSubview(textField)
            cell?.textField = textField
            
            // Устанавливаем констрейнты
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4),
                imageView.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),
                
                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
            ])
        }
        
        // Получаем URL файла
        let fileURL = storedItems[row]
        
        // Проверяем доступность файла
        let isFileAvailable = FileManager.default.fileExists(atPath: fileURL.path)
        
        // Устанавливаем иконку файла
        cell?.imageView?.image = NSWorkspace.shared.icon(forFile: fileURL.path)
        
        // Устанавливаем имя файла
        cell?.textField?.stringValue = fileURL.lastPathComponent
        
        // Изменяем прозрачность ячейки в зависимости от доступности файла
        cell?.alphaValue = isFileAvailable ? 1.0 : 0.5
        
        return cell
    }
    
    // MARK: - Drag & Drop
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        return .copy
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let items = info.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] else { return false }
        
        var added = false
        for item in items {
            // Проверяем, нет ли уже такого файла на полке
            if !storedItems.contains(where: { $0.path == item.path }) {
                storedItems.append(item)
                added = true
            }
        }
        
        if added {
            tableView.reloadData()
            saveStoredItems()
        }
        
        return added
    }
    
    // MARK: - TableView Delegate
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }
    
    @objc func tableViewDoubleClick(_ sender: Any?) {
        guard let tableView = sender as? NSTableView else { return }
        let clickedRow = tableView.clickedRow
        if clickedRow >= 0 && clickedRow < storedItems.count {
            NSWorkspace.shared.open(storedItems[clickedRow])
        }
    }
    
    // MARK: - Storage
    private func saveStoredItems() {
        let bookmarks = storedItems.compactMap { url -> Data? in
            try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        UserDefaults.standard.set(bookmarks, forKey: "StoredItems")
    }
    
    private func loadStoredItems() {
        guard let bookmarks = UserDefaults.standard.array(forKey: "StoredItems") as? [Data] else { return }
        storedItems = bookmarks.compactMap { bookmark -> URL? in
            var isStale = false
            return try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
        }
        validateStoredItems()
        tableView.reloadData()
    }
    
    // Добавим методы для исходящего drag&drop
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        return storedItems[row] as NSURL
    }
    
    func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forRowIndexes rowIndexes: IndexSet) {
        // Можно добавить анимацию или визуальный эффект при начале перетаскивания
    }
    
    func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        // Можно добавить анимацию или визуальный эффект при окончании перетаскивания
    }
}
