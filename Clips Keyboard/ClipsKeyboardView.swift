//
//  ClipsKeyboardView.swift
//  Clips Keyboard
//
//  Created by Bill Wu on 1/3/19.
//  Copyright © 2019 William Wu. All rights reserved.
//

import UIKit

protocol ClipsKeyboardViewDelegate: class {
    var currentFolder: Folder! { get }
    var isRootFolder: Bool { get }
    var subfolders: [Folder] { get }
    var clips: [Clip] { get }
    func selectFolder(_ folder: Folder)
    func selectClip(_ clip: Clip)
    
    func insertText(_ text: String)
    func deleteBackwards()
    func addLastCopied(_ text: String)
}

class ClipsKeyboardView: UIView, UICollectionViewDelegate, UICollectionViewDataSource {
    
    //private var titles: [String?] = []
    //private var strings: [String] = []
    //private var indices: [Int] = []
    private var filteredClips: [Clip] = []
    private var lastCopied: String?
    private var pasteboardChangeCount: Int = 0
    private static let numItemsOnPage: Int = 5
    
    @IBOutlet weak var lastCopiedLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var previousColumnButton: KeyboardButton!
    @IBOutlet weak var nextKeyboardButton: KeyboardButton!
    @IBOutlet weak var spaceKey: KeyboardButton!
    @IBOutlet weak var backspaceKey: KeyboardButton!
    @IBOutlet weak var nextColumnButton: KeyboardButton!
    @IBOutlet weak var messageLabel: UILabel!
    private var backspaceKeyTimer: Timer?
    private var backspaceKeyIsDown: Bool = false
    
    @IBOutlet weak var spaceKeyToNextKeyboardButtonConstraint: NSLayoutConstraint!
    @IBOutlet weak var spaceKeyToPreviousColumnButtonConstraint: NSLayoutConstraint!
    
    weak var delegate: ClipsKeyboardViewDelegate!

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.collectionView.register(UINib(nibName: "KeyboardFolderCell", bundle: nil), forCellWithReuseIdentifier: "KeyboardFolderCell")
        self.collectionView.register(UINib(nibName: "KeyboardClipCell", bundle: nil), forCellWithReuseIdentifier: "KeyboardClipCell")
        self.collectionViewLayout.itemSize = CGSize(width: UIScreen.main.bounds.size.width, height: 44)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ClipsKeyboardView.updateLastCopied), name: UIPasteboard.changedNotification, object: nil)
        
        if self.traitCollection.userInterfaceStyle == .dark {
            self.previousColumnButton.backgroundColor = UIColor(named: "Key Dark")
            print("dark")
        }
        else if self.traitCollection.userInterfaceStyle == .unspecified {
            print("unspecified")
        }
        else {
            self.previousColumnButton.backgroundColor = UIColor(named: "Key")
            print("light")
        }
    }
    
    func setNextKeyboardButtonVisible(_ visible: Bool) {
        self.nextKeyboardButton.isHidden = !visible
        if visible {
            self.spaceKeyToNextKeyboardButtonConstraint.priority = .defaultHigh
            self.spaceKeyToPreviousColumnButtonConstraint.priority = .defaultLow
        }
        else {
            self.spaceKeyToNextKeyboardButtonConstraint.priority = .defaultLow
            self.spaceKeyToPreviousColumnButtonConstraint.priority = .defaultHigh
        }
    }
    
    func loadData() {
        // filter clips to include only those with (plain)text
        self.filteredClips = []
        for clip in self.delegate.clips {
            if ClipboardManager.containsText(item: clip.contents) {
                self.filteredClips.append(clip)
            }
        }
        
        self.collectionView.reloadData()
        if self.filteredClips.count == 0 {
            self.showEmptyMessage()
        }
        else {
            self.setMessageLabelVisible(false)
        }
        
        self.updateLastCopied()
    }
    
    @objc func updateLastCopied() {
        if self.pasteboardChangeCount != UIPasteboard.general.changeCount {
            self.lastCopied = ClipboardManager.stringFromItem(ClipboardManager.retrieveFromPasteboard())
            self.lastCopiedLabel.text = self.lastCopied
            self.pasteboardChangeCount = UIPasteboard.general.changeCount
        }
    }
    
    func setMessageLabelVisible(_ visible: Bool) {
        self.messageLabel.isHidden = !visible
    }
    
    func setMessageLabelText(_ text: String) {
        self.messageLabel.text = text
    }
    
    func showErrorMessage() {
        self.setMessageLabelText(AppStrings.KEYBOARD_ERROR_MESSAGE)
        self.setMessageLabelVisible(true)
    }
    
    func showEmptyMessage() {
        self.setMessageLabelText(AppStrings.KEYBOARD_EMPTY_MESSAGE)
        self.setMessageLabelVisible(true)
    }
    
    // MARK: - Actions
    
    @IBAction func insertLastCopied(_ sender: UIButton) {
        if let string = self.lastCopied {
            self.delegate.insertText(string)
        }
    }
    
    @IBAction func addLastCopied(_ sender: UIButton) {
        if let string = self.lastCopied {
            self.delegate.addLastCopied(string)
        }
    }
    
    @IBAction func space(_ sender: UIButton) {
        self.delegate.insertText(" ")
    }
    
    @IBAction func backspaceDown(_ sender: UIButton) {
        self.backspace()
        self.backspaceKeyIsDown = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if (self.backspaceKeyIsDown) {
                self.backspaceKeyTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(ClipsKeyboardView.backspace), userInfo: nil, repeats: true)
            }
        }
    }
    
    @IBAction func backspaceUp(_ sender: UIButton) {
        self.backspaceKeyTimer?.invalidate()
        self.backspaceKeyIsDown = false
    }
    
    @objc func backspace() {
        self.delegate.deleteBackwards()
    }
    
    @IBAction func scrollToPreviousColumn(_ sender: UIButton) {
        let col: Int = self.getCurrentColumn()
        if col > 0 {
            let indexPath: IndexPath = IndexPath(row: (col - 1) * ClipsKeyboardView.numItemsOnPage, section: 0)
            self.collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        }
    }
    
    @IBAction func scrollToNextColumn(_ sender: UIButton) {
        let col: Int = self.getCurrentColumn()
        if col < (self.filteredClips.count - 1) / 4 {
            let indexPath: IndexPath = IndexPath(row: (col + 1) * ClipsKeyboardView.numItemsOnPage, section: 0)
            self.collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        }
    }
    
    // MARK: - Private instance methods
    
    private func getCurrentColumn() -> Int {
        let indexPaths: [IndexPath] = self.collectionView.indexPathsForVisibleItems
        if let indexPath = indexPaths.first {
            return indexPath.row / ClipsKeyboardView.numItemsOnPage
        }
        return 0
    }
    
    // MARK: - Collection view data source
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return (self.delegate.isRootFolder ? 0 : 1) + self.delegate.subfolders.count + self.filteredClips.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let offset = self.delegate.isRootFolder ? 0 : 1
        if !self.delegate.isRootFolder && indexPath.row == 0 {
            let cell: KeyboardFolderCell = collectionView.dequeueReusableCell(withReuseIdentifier: "KeyboardFolderCell", for: indexPath) as! KeyboardFolderCell
            cell.setFormat(goesToSuperfolder: true)
            cell.setName(self.delegate.currentFolder.superfolder!.name)
            return cell
        }
        else if indexPath.row < self.delegate.subfolders.count + offset {
            let folder: Folder = self.delegate.subfolders[indexPath.row - offset]
            let cell: KeyboardFolderCell = collectionView.dequeueReusableCell(withReuseIdentifier: "KeyboardFolderCell", for: indexPath) as! KeyboardFolderCell
            cell.setFormat(goesToSuperfolder: false)
            cell.setName(folder.name)
            return cell
        }
        else {
            let index = indexPath.row - self.delegate.subfolders.count - offset
            let clip: Clip = self.filteredClips[index]
            let cell: KeyboardClipCell = collectionView.dequeueReusableCell(withReuseIdentifier: "KeyboardClipCell", for: indexPath) as! KeyboardClipCell
            cell.setClip(clip)
            return cell
        }
        /*let cell: KeyboardClipCell = collectionView.dequeueReusableCell(withReuseIdentifier: "KeyboardClipCell", for: indexPath) as! KeyboardClipCell
        cell.setup(title: self.titles[indexPath.row], contents: self.strings[indexPath.row], index: self.indices[indexPath.row])
        return cell*/
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let offset = self.delegate.isRootFolder ? 0 : 1
        if !self.delegate.isRootFolder && indexPath.row == 0 {
            self.delegate.selectFolder(self.delegate.currentFolder.superfolder!)
        }
        else if indexPath.row < self.delegate.subfolders.count + offset {
            self.delegate.selectFolder(self.delegate.subfolders[indexPath.row - offset])
        }
        else {
            let index = indexPath.row - self.delegate.subfolders.count - offset
            self.delegate.selectClip(self.filteredClips[index])
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        if let cell: UICollectionViewCell = collectionView.cellForItem(at: indexPath) {
            cell.backgroundColor = UIColor.lightGray
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        if let cell: UICollectionViewCell = collectionView.cellForItem(at: indexPath){
            UIView.animate(withDuration: 0.2) {
                cell.backgroundColor = nil
            }
        }
    }
    
}
