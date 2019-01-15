//
//  ViewController.swift
//  VideoTrimmerView
//
//  Created by 田向阳 on 2019/1/14.
//  Copyright © 2019 田向阳. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, VideoTrimmerViewDelegate {
   
    var playerView = UIView()
    var trimmerView: VideoTrimmerView!
    var player: AVPlayer?
    var isPlaying = true
    var startTime: CGFloat = 0
    var endTime: CGFloat = 15
    
    var timer: DispatchSourceTimer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        playerView.frame = self.view.bounds
        view.addSubview(playerView)
        
        let path = Bundle.main.path(forResource: "123", ofType: "mp4") ?? ""
        player = AVPlayer(url: URL(fileURLWithPath: path))
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        playerView.layer.addSublayer(playerLayer)
        playerLayer.frame = playerView.bounds
        player?.play()
        playerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(controlPlayer)))
        
        trimmerView = VideoTrimmerView(frame: CGRect(x: 14, y: view.height - 50 - 54, width: view.width - 2 * 14, height: 50), videoURL: URL(fileURLWithPath: path), leftThumImage: UIImage(named: "video_crop_l"), rightThumImage: UIImage(named: "video_crop_r"), maxLength: 15, minLength: 3)
        trimmerView.delegate = self
        view.addSubview(trimmerView)
        addNotification()
        addTimer()
    }
    
    //MARK:VideoTrimmerViewDelegate
    func trimmerViewPositionDidChange(startTime: CGFloat, endTime: CGFloat) {
        self.startTime = startTime
        self.endTime = endTime
        self.seek(self.startTime)
        print("startTime:\(startTime) endTime:\(endTime) duration:\(endTime - startTime)")
    }
    
    func trimmerViewSliderChange(startTime: CGFloat) {
       self.seek(startTime)
    }
    
    func trimmerBeginChange(){
        player?.pause()
        removeTimer()
    }

    private func addTimer() {
        removeTimer()
        self.timer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(), queue: DispatchQueue.main)
        self.timer?.schedule(deadline: .now(), repeating: .milliseconds(10), leeway: .milliseconds(0))
        self.timer?.setEventHandler(handler: { [weak self] in
            guard let self = self else{ return }
            if !self.isPlaying {return}
            let currentTime = CMTimeGetSeconds(self.player?.currentTime() ?? .zero)
            if currentTime >= Float64(self.endTime) {
                self.seek(self.startTime)
            }
            DispatchQueue.main.async {
                self.trimmerView.updateCurrentTime(currentTime)
            }
        })
        self.timer?.resume()
    }
    
    private func removeTimer() {
        guard timer != nil else {
            return
        }
        self.timer?.cancel()
        self.timer = nil
    }
    
    private func addNotification(){
        NotificationCenter.default.addObserver(self, selector: #selector(playToEnd), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
    }

    @objc private func playToEnd(sender: NSNotification){
        if let item = sender.object as? AVPlayerItem, item == player?.currentItem {
            self.seek(self.startTime)
        }
    }
    
    private func seek(_ time: CGFloat) {
        let timeScale = self.player?.currentItem?.asset.duration.timescale ?? 1
        let cmTime = CMTimeMakeWithSeconds(Float64(time), preferredTimescale: timeScale)
        self.player?.seek(to: cmTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero, completionHandler:{ [weak self] (finish) in
            guard let self = self else{ return }
            if self.isPlaying {
                self.player?.play()
                self.addTimer()
            }
        })
    }
    
    @objc private func controlPlayer(){
        if isPlaying {
            player?.pause()
            isPlaying = false
            removeTimer()
        }else{
            addTimer()
            player?.play()
            isPlaying = true
        }
    }

}

