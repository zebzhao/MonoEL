//
//  LyricsView.swift
//  SpotlightLyrics
//
//  Created by Scott Rong on 2017/4/2.
//  Copyright © 2017 Scott Rong. All rights reserved.
//

import UIKit

@objc public protocol LyricsViewTimerDelegate {
    func lyricTimerDidSetElapsedTime(elapsedTime: TimeInterval)
}

open class LyricsView: UITableView, UITableViewDataSource, UITableViewDelegate {
    
    private var parser: LyricsParser? = nil
    private var lyricsViewModels: [LyricsCellViewModel] = []
    private var lastIndex: Int? = nil
    private(set) public var timer: LyricsViewTimer = LyricsViewTimer()
    
    // MARK: Public properties
    
    public var currentLyric: String? {
        get {
            guard let lastIndex = lastIndex else {
                return nil
            }
            guard lastIndex < lyricsViewModels.count else {
                return nil
            }
            
            return lyricsViewModels[lastIndex].lyric
        }
    }
    
    public var lyrics: String? = nil {
        didSet {
            lastIndex = 0
            reloadViewModels()
        }
    }
    
    public var lyricFont: UIFont = .systemFont(ofSize: 16) {
        didSet {
            reloadViewModels()
        }
    }
    
    public var lyricHighlightedFont: UIFont = .systemFont(ofSize: 16) {
        didSet {
            reloadViewModels()
        }
    }
    
    public var lyricTextColor: UIColor = .black {
        didSet {
            reloadViewModels()
        }
    }
    
    public var lyricHighlightedTextColor: UIColor = .lightGray {
        didSet {
            reloadViewModels()
        }
    }
    
    public var lineSpacing: CGFloat = 16 {
        didSet {
            reloadViewModels()
        }
    }
    
    // MARK: Initializations
    
    override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    private func commonInit() {
        register(LyricsCell.self, forCellReuseIdentifier: "LyricsCell")
        separatorStyle = .none
        clipsToBounds = true
        
        dataSource = self
        delegate = self
        
        timer.lyricsView = self
    }
    
    // MARK: UITableViewDataSource

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return lyricsViewModels.count
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cellViewModel = self.lyricsViewModels[indexPath.row]
        return lineSpacing + cellViewModel.calcHeight(containerWidth: self.bounds.width)
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = dequeueReusableCell(withIdentifier: "LyricsCell", for: indexPath) as! LyricsCell
        cell.update(with: lyricsViewModels[indexPath.row])
        return cell
    }
    
    // MARK: UITableViewDelegate
    
    public func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let point = CGPoint(x: 0, y: self.contentOffset.y + self.visibleSize.height/2 - 20)
        if let index = self.indexPathForRow(at: point)?.row {
            if index != lastIndex {
                if let lIndex=lastIndex {
                    if lIndex < lyricsViewModels.count {
                        lyricsViewModels[lIndex].highlighted = false
                    }
                }
                lastIndex = index
                if index < lyricsViewModels.count {
                    lyricsViewModels[index].highlighted = true
                    if let lyrics=parser?.lyrics {
                        if isScrollEnabled && abs(timer.elapsedTime - lyrics[index].time) >= 0.5 {
                            timer.elapsedTime = lyrics[index].time
                        }
                        
                    }
                }
            }
        } else if let lIndex=lastIndex {
            if lIndex < lyricsViewModels.count {
                lyricsViewModels[lIndex].highlighted = false
            }
            lastIndex = nil
        }
    }
    
    // MARK:
    
    private func reloadViewModels() {
        lyricsViewModels.removeAll()
        
        guard let lyrics = self.lyrics?.emptyToNil() else {
            reloadData()
            return
        }
        
        parser = LyricsParser(lyrics: lyrics)
        
        for lyric in parser!.lyrics {
            let viewModel = LyricsCellViewModel.cellViewModel(lyric: lyric.text,
                                                              font: lyricFont,
                                                              highlightedFont: lyricHighlightedFont,
                                                              textColor: lyricTextColor,
                                                              highlightedTextColor: lyricHighlightedTextColor
            )
            lyricsViewModels.append(viewModel)
        }
        reloadData()
        contentInset = UIEdgeInsets(top: frame.height / 2, left: 0, bottom: frame.height / 2, right: 0)
    }
    
    // MARK: Controls
    
    internal func scroll(toTime time: TimeInterval, animated: Bool) {
        guard let lyrics = parser?.lyrics else {
            return
        }
        
        guard let index = lyrics.firstIndex(where: { $0.time >= time }) else {
            // when no lyric is before the time passed
            return
        }
        
        guard lastIndex == nil || index - 1 != lastIndex else {
            return
        }
        
        if index > 0 {
            let rowRect = self.rectForRow(at: IndexPath(row: index - 1, section: 0))
            let point = CGPoint(x: 0, y: rowRect.minY - self.visibleSize.height/2 + 30)
            var delay: TimeInterval = 0
            if index > 1 {
                if (lyrics[index - 1].time - lyrics[index - 2].time) < 0.7 {
                    delay = 0.3
                }
            }
            UIView.animate(withDuration: 0.38, delay: delay, options: .curveLinear, animations: {
                self.setContentOffset(point, animated: false)
            }, completion: nil)
            //scrollToRow(at: IndexPath(row: index - 1, section: 0), at: .middle, animated: animated)
        }
    }
}

internal class LyricsCell: UITableViewCell {
    
    private var lyricLabel: UILabel!
    
    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        commitInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commitInit()
    }
    
    private func commitInit() {
        lyricLabel = UILabel(frame: CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height))
        lyricLabel.numberOfLines = 2
        lyricLabel.textAlignment = .left
        lyricLabel.backgroundColor = .clear
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(lyricLabel)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        lyricLabel.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
    }
    
    public override var isHighlighted: Bool {
        didSet {
            applyViewModel()
        }
    }
    
    public func update(with viewModel: LyricsCellViewModel) {
        self.viewModel = viewModel
    }
    
    private func applyViewModel() {
        guard let viewModel = self.viewModel else {
            return
        }
        
        lyricLabel.attributedText = isHighlighted ? viewModel.highlightedAttributedString : viewModel.attributedString
        lyricLabel.sizeThatFits(CGSize(width: bounds.width, height: bounds.height))
        
        viewModel.cell = self
    }
    
    private weak var viewModel : LyricsCellViewModel? = nil
}

internal class LyricsCellViewModel {
    
    // MARK: Properties
    
    public var lyric: String {
        didSet {
            update()
        }
    }
    
    public var font: UIFont {
        didSet {
            update()
        }
    }
    
    public var highlightedFont: UIFont {
        didSet {
            update()
        }
    }
    
    public var textColor: UIColor {
        didSet {
            update()
        }
    }
    
    public var highlightedTextColor: UIColor {
        didSet {
            update()
        }
    }
    
    public var highlighted: Bool = false {
        didSet {
            cell?.isHighlighted = highlighted
        }
    }
    
    let paragraphStyle = NSMutableParagraphStyle()
    
    public static func cellViewModel(lyric: String, font: UIFont, highlightedFont: UIFont, textColor: UIColor, highlightedTextColor: UIColor) -> LyricsCellViewModel {
        return LyricsCellViewModel(lyric: lyric,
                                   font: font,
                                   highlightedFont: highlightedFont,
                                   textColor: textColor,
                                   highlightedTextColor: highlightedTextColor)
    }
    
    fileprivate init(lyric: String, font: UIFont, highlightedFont: UIFont, textColor: UIColor, highlightedTextColor: UIColor) {
        self.lyric = lyric
        self.font = font
        self.highlightedFont = highlightedFont
        self.textColor = textColor
        self.highlightedTextColor = highlightedTextColor
        self.paragraphStyle.firstLineHeadIndent = 0
        self.paragraphStyle.headIndent = 32
        update()
    }
    
    private func update() {
        // produce the attributedString
        attributedString = NSAttributedString(string: lyric, attributes: [.font: font,
                                                                          .foregroundColor: textColor,
                                                                          .paragraphStyle: paragraphStyle
            ])
        highlightedAttributedString = NSAttributedString(
            string: lyric, attributes: [.font: highlightedFont,
                                        .foregroundColor: highlightedTextColor,
                                        .paragraphStyle: paragraphStyle
            ])
        cell?.update(with: self)
    }
    
    public var attributedString: NSAttributedString? = nil
    public var highlightedAttributedString: NSAttributedString? = nil
    
    public func calcHeight(containerWidth: CGFloat) -> CGFloat {
        let boundingSize = CGSize(width: containerWidth, height: 9999)
        if (highlighted) {
            return highlightedAttributedString?.boundingRect(with: boundingSize, options: .usesLineFragmentOrigin, context: nil).height ?? 0
        } else {
            return attributedString?.boundingRect(with: boundingSize, options: .usesLineFragmentOrigin, context: nil).height ?? 0
        }
    }
    
    internal weak var cell: LyricsCell? = nil
}

public struct LyricsHeader {
    // ti
    public var title: String?
    // ar
    public var author: String?
    // al
    public var album: String?
    // by
    public var by: String?
    // offset
    public var offset: TimeInterval = 0
    // re
    public var editor: String?
    // ve
    public var version: String?
}


public class LyricsItem {
    
    public init(time: TimeInterval, text: String = "") {
        self.time = time
        self.text = text
    }
    
    public var time: TimeInterval
    public var text: String
}

public class LyricsViewTimer {
    public var elapsedTime: TimeInterval = 0 {
        didSet {
            if let delegate=delegate {
                delegate.lyricTimerDidSetElapsedTime(elapsedTime: elapsedTime)
            }
        }
    }
    public weak var delegate: LyricsViewTimerDelegate?
    private let TICK_INTERVAL: TimeInterval = 0.1
    private var timer: Timer? = nil
    internal weak var lyricsView: LyricsView? = nil
    
    public var isPaused: Bool {
        get {
            return timer == nil 
        }
    }
    
    // MARK: Controls
    
    public func play() {
        guard timer == nil else {
            return
        }
        lyricsView?.isScrollEnabled = false
        timer = Timer.scheduledTimer(timeInterval: TICK_INTERVAL, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
    }
    
    public func pause() {
        guard timer != nil else {
            return
        }
        lyricsView?.isScrollEnabled = true
        timer?.invalidate()
        timer = nil
    }
    
    public func seek(toTime time: TimeInterval) {
        elapsedTime = time
        lyricsView?.scroll(toTime: time, animated: true)
    }
    
    // MARK: tick
    
    @objc private func tick() {
        elapsedTime += TICK_INTERVAL
        seek(toTime: elapsedTime)
    }
}

extension CharacterSet {
    public static var quotes = CharacterSet(charactersIn: "\"'")
}

extension String {
    public func emptyToNil() -> String? {
        return self == "" ? nil : self
    }
    
    public func blankToNil() -> String? {
        return self.trimmingCharacters(in: .whitespacesAndNewlines) == "" ? nil : self
    }
}
