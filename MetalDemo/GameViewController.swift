//
//  GameViewController.swift
//  MetalDemo
//
//  Created by Brennan Andruss on 6/28/25.
//

import Cocoa
import MetalKit
import GameController

// Our macOS specific view controller
class GameViewController: NSViewController {

    var renderer: Renderer!
    var mtkView: MTKView!

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let mtkView = self.view as? MTKView else {
            print("View attached to GameViewController is not an MTKView")
            return
        }

        // Select the device to render with.  We choose the default device
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }
        
        // Check for Metal 4 support
        if !defaultDevice.supportsFamily(.metal4) {
            print("Metal 4 is not supported")
            return
        }

        mtkView.device = defaultDevice

        guard let newRenderer = Renderer(metalKitView: mtkView) else {
            print("Renderer cannot be initialized")
            return
        }

        renderer = newRenderer

        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)

        mtkView.delegate = renderer
        
        // Input
        
        // Keyboard
        NotificationCenter.default.addObserver(forName: NSNotification.Name.GCKeyboardDidConnect, object: nil, queue: nil) {
            (note) in
            guard let _keyboard = note.object as? GCKeyboard else {
                return
            }
            
            self.renderer.keyboards.append(_keyboard)
            
            // Register callbacks
            _keyboard.keyboardInput?.keyChangedHandler = {
                (keyboardInput, controllerButton, key, isPressed) in
                if keyboardInput.button(forKeyCode: .keyW)!.value > 0.5 {
                    print("Key W pressed")
                }
                if keyboardInput.button(forKeyCode: .keyA)!.value > 0.5 {
                    print("Key A pressed")
                }
                if keyboardInput.button(forKeyCode: .keyS)!.value > 0.5 {
                    print("Key S pressed")
                }
                if keyboardInput.button(forKeyCode: .keyD)!.value > 0.5 {
                    print("Key D pressed")
                }
                if keyboardInput.button(forKeyCode: .keyE)!.value > 0.5 {
                    print("Key E pressed")
                }
                if keyboardInput.button(forKeyCode: .keyQ)!.value > 0.5 {
                    print("Key Q pressed")
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.GCKeyboardDidDisconnect, object: nil, queue: nil) {
            (note) in
            guard let _keyboard = note.object as? GCKeyboard else {
                return
            }
            
            self.renderer.keyboards.removeAll { (value) in
                return value == _keyboard
            }
        }
        
        // disable pop sound?
        
        // Mouse
        NotificationCenter.default.addObserver(forName: NSNotification.Name.GCMouseDidConnect, object: nil, queue: nil) {
            (note) in
            guard let _mouse = note.object as? GCMouse else {
                return
            }
            
            // Register callbacks
            _mouse.mouseInput?.mouseMovedHandler = {
                (mouseInput, deltaX, deltaY) in
                if mouseInput.leftButton.isPressed {
                    let windowSize = self.view.window?.contentView?.frame.size
                    let normX = deltaX / Float(windowSize!.width)
                    let normY = deltaY / Float(windowSize!.height)
                    
                    self.renderer.rightJoystick.x += normX
                    self.renderer.rightJoystick.y += normY
                }
            }
        }
    }
}
