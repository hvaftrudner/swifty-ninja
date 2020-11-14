//
//  GameScene.swift
//  project 23
//
//  Created by Kristoffer Eriksson on 2020-11-11.
//

import SpriteKit
import AVFoundation

enum ForceBomb {
    case never, always, random
}

enum sequenceType: CaseIterable{
    case oneNoBomb, one, twoWithOneBomb, two, three, four, chain, fastChain
}

class GameScene: SKScene {
    
    var gameScore : SKLabelNode!
    var score : Int = 0 {
        didSet{
            gameScore.text = "Score: \(score)"
        }
    }
    
    var livesImages = [SKSpriteNode]()
    var lives = 3
    
    var activeSliceBG : SKShapeNode!
    var activeSliceFG : SKShapeNode!
    
    var activeSlicePoints = [CGPoint]()
    
    var isSwoshSoundActive = false
    
    var activeEnemies = [SKSpriteNode]()
    
    var bombSoundEffect : AVAudioPlayer?
    
    var popupTime = 0.9
    var sequence = [sequenceType]()
    var sequencePosition = 0
    var chainDelay = 3.0
    var nextSequenceQueue = true
    
    var isGameEnded = false
    
    //challenge 1 constants
    
    let positionRange: ClosedRange<Int> = 64...960
    //cg float to conform to positional
    let quarterScreen: CGFloat = 256
    let halfScreen: CGFloat = 512
    let threeQuarterScreen: CGFloat = 768
    
    let enemyXVelDict = [
        "farLeft": Int.random(in: 8...15),
        "left": Int.random(in: 3...5),
        "right": -Int.random(in: 3...5),
        "farRight": -Int.random(in: 8...15)
    ]
    
    //using CGfloat range for positional
    //using Int range for others
    let angularVel: ClosedRange<CGFloat> = -3...3
    let yVel: ClosedRange<Int> = 24...32
    
    let enemyBodyRadius = 64
    let multiplier = 40
    
    override func didMove(to view: SKView) {
        let background = SKSpriteNode(imageNamed: "sliceBackground")
        background.position = CGPoint(x: 512, y: 384)
        background.blendMode = .replace
        background.zPosition = -1
        addChild(background)
        
        physicsWorld.gravity = CGVector(dx: 0, dy: -6)
        physicsWorld.speed = 0.85
        
        createScore()
        createLives()
        createSlices()
        
        sequence = [.oneNoBomb, .oneNoBomb, .twoWithOneBomb, .twoWithOneBomb, .three, .one, .chain]
        
        for _ in 0...1000{
            if let nextSequence = sequenceType.allCases.randomElement(){
                sequence.append(nextSequence)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2){
            [weak self] in self?.tossEnemies()
        }
        
        if lives < 1 {
            isGameEnded = true
            endGame(triggeredByBomb: false)
        }
    }
    
    func createScore(){
        gameScore = SKLabelNode(fontNamed: "chalkduster")
        gameScore.horizontalAlignmentMode = .left
        gameScore.fontSize = 48
        addChild(gameScore)
        gameScore.position = CGPoint(x: 8, y: 8)
        score = 0
        
    }
    
    func createLives(){
        for i in 0..<3{
            let spriteNode = SKSpriteNode(imageNamed: "sliceLife")
            spriteNode.position = CGPoint(x: CGFloat(834 + (i * 70)), y: 720)
            addChild(spriteNode)
            livesImages.append(spriteNode)
        }
    }
    
    func createSlices(){
        activeSliceBG = SKShapeNode()
        activeSliceBG.zPosition = 2
        
        activeSliceFG = SKShapeNode()
        activeSliceFG.zPosition = 3
        
        activeSliceBG.strokeColor = UIColor(red: 1, green: 0.9, blue: 0, alpha: 1)
        activeSliceBG.lineWidth = 9
        
        activeSliceFG.strokeColor = UIColor.white
        activeSliceFG.lineWidth = 5
        
        addChild(activeSliceBG)
        addChild(activeSliceFG)
    }
    
    func redrawActiveSlice(){
        if activeSlicePoints.count < 2 {
            activeSliceBG.path = nil
            activeSliceFG.path = nil
            return
        }
        
        if activeSlicePoints.count > 12 {
            activeSlicePoints.removeFirst(activeSlicePoints.count - 12)
        }
        
        let path = UIBezierPath()
        path.move(to: activeSlicePoints[0])
        
        for i in 1..<activeSlicePoints.count {
            path.addLine(to: activeSlicePoints[i])
        }
        
        activeSliceBG.path = path.cgPath
        activeSliceFG.path = path.cgPath
        
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isGameEnded == false else {return}
        
        guard let touch = touches.first else {return}
        let location = touch.location(in: self)
        
        activeSlicePoints.append(location)
        
        redrawActiveSlice()
        
        if !isSwoshSoundActive{
            playSwoshSound()
        }
        
        let nodesAtPoint = nodes(at: location)
        for case let node as SKSpriteNode in nodesAtPoint{
            if node.name == "enemy"{
                //destroy penguin
                if let emitter = SKEmitterNode(fileNamed: "sliceHitEnemy"){
                    emitter.position = node.position
                    addChild(emitter)
                }
                node.name = ""
                node.physicsBody?.isDynamic = false
                
                let scaleOut = SKAction.scale(to: 0.001, duration: 0.2)
                let fadeOut = SKAction.fadeOut(withDuration: 0.2)
                
                let group = SKAction.group([scaleOut, fadeOut])
                
                let seq = SKAction.sequence([group, .removeFromParent()])
                node.run(seq)
                
                score += 1
                
                if let index = activeEnemies.firstIndex(of: node){
                    activeEnemies.remove(at: index)
                }
                run(SKAction.playSoundFileNamed("whack.caf", waitForCompletion: false))
                
            } else if node.name == "fastEnemy"{
                //destroy fastpenguin
                if let emitter = SKEmitterNode(fileNamed: "sliceHitEnemy"){
                    emitter.position = node.position
                    addChild(emitter)
                }
                node.name = ""
                node.physicsBody?.isDynamic = false
                
                let scaleOut = SKAction.scale(to: 0.001, duration: 0.2)
                let fadeOut = SKAction.fadeOut(withDuration: 0.2)
                
                let group = SKAction.group([scaleOut, fadeOut])
                
                let seq = SKAction.sequence([group, .removeFromParent()])
                node.run(seq)
                
                score += 3
                
                if let index = activeEnemies.firstIndex(of: node){
                    activeEnemies.remove(at: index)
                }
                run(SKAction.playSoundFileNamed("whack.caf", waitForCompletion: false))
                
            } else if node.name == "bomb"{
                //destroy bomb
                guard let bombContainer = node.parent as? SKSpriteNode else {continue}
                
                if let emitter = SKEmitterNode(fileNamed: "sliceHitBomb"){
                    emitter.position = bombContainer.position
                    addChild(emitter)
                }
                
                node.name = ""
                bombContainer.physicsBody?.isDynamic = false
                
                let scaleOut = SKAction.scale(to: 0.001, duration: 0.2)
                let fadeOut = SKAction.fadeOut(withDuration: 0.2)
                
                let group = SKAction.group([scaleOut, fadeOut])
                
                let seq = SKAction.sequence([group, .removeFromParent()])
                bombContainer.run(seq)
                
                if let index = activeEnemies.firstIndex(of: bombContainer){
                    activeEnemies.remove(at: index)
                }
                
                run(SKAction.playSoundFileNamed("explosion.caf", waitForCompletion: false))
                
                endGame(triggeredByBomb: true)
            }
        }
    }
    
    func endGame(triggeredByBomb: Bool){
        guard isGameEnded == false else {return}
        
        isGameEnded = true
        physicsWorld.speed = 0
        isUserInteractionEnabled = false
        
        bombSoundEffect?.stop()
        bombSoundEffect = nil
        
        if triggeredByBomb {
            livesImages[0].texture = SKTexture(imageNamed: "sliceLifeGone")
            livesImages[1].texture = SKTexture(imageNamed: "sliceLifeGone")
            livesImages[2].texture = SKTexture(imageNamed: "sliceLifeGone")
        }
        //end game text
        let endgametext = SKLabelNode(fontNamed: "chalkduster")
        endgametext.zPosition = 5
        endgametext.position = CGPoint(x: 512, y: 368)
        endgametext.text = "Game over!"
        endgametext.fontSize = 50
        addChild(endgametext)
        
        let endScore = SKLabelNode(fontNamed: "chalkduster")
        endScore.zPosition = 4
        endScore.position = CGPoint(x: 512, y: 250)
        endScore.text = "Score: \(score)"
        endScore.fontSize = 40
        addChild(endScore)
        
    }
    
    func playSwoshSound(){
        isSwoshSoundActive = true
        let random = Int.random(in: 1...3)
        
        let soundName = "swoosh\(random).caf"
        
        let swooshSound = SKAction.playSoundFileNamed(soundName, waitForCompletion: true)
        
        run(swooshSound) { [weak self] in
            self?.isSwoshSoundActive = false
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeSliceBG.run(SKAction.fadeOut(withDuration: 0.25))
        activeSliceFG.run(SKAction.fadeOut(withDuration: 0.25))
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {return}
        activeSlicePoints.removeAll(keepingCapacity: true)
        
        let location = touch.location(in: self)
        activeSlicePoints.append(location)
        
        redrawActiveSlice()
        
        activeSliceBG.removeAllActions()
        activeSliceFG.removeAllActions()
        
        activeSliceBG.alpha = 1
        activeSliceFG.alpha = 1
    }
    
    func createEnemy(forceBomb: ForceBomb = .random){
        let enemy : SKSpriteNode
        var enemyType = Int.random(in: 0...7)
        
        if forceBomb == .never{
            enemyType = 0
        } else if forceBomb == .always{
            enemyType = 1
        }
        
        if enemyType == 0 {
            //bombcode
            enemy = SKSpriteNode()
            enemy.zPosition = 1
            enemy.name = "bombContainer"
            
            let bombimage = SKSpriteNode(imageNamed: "sliceBomb")
            bombimage.name = "bomb"
            enemy.addChild(bombimage)
            
            if bombSoundEffect != nil {
                bombSoundEffect?.stop()
                bombSoundEffect = nil
            }
            
            if let path = Bundle.main.url(forResource: "sliceBombFuse", withExtension: "caf"){
                if let sound = try? AVAudioPlayer(contentsOf: path){
                    bombSoundEffect = sound
                    sound.play()
                }
            }
            
            if let emitter = SKEmitterNode(fileNamed: "sliceFuse"){
                emitter.position = CGPoint(x: 76, y: 64)
                
            }
        } else if enemyType == 7 {
            enemy = SKSpriteNode(imageNamed: "penguin")
            run(SKAction.playSoundFileNamed("launch.caf", waitForCompletion: false))
            enemy.name = "fastEnemy"
        } else {
            enemy = SKSpriteNode(imageNamed: "penguin")
            run(SKAction.playSoundFileNamed("launch.caf", waitForCompletion: false))
            enemy.name = "enemy"
        }
        
        let randomPosition = CGPoint(x: Int.random(in: positionRange), y: -128)
        enemy.position = randomPosition
        
        let randomAngularVel = CGFloat.random(in: angularVel)
        let randomXVel : Int
        //challenge constant to remove magic numbers
        
        if randomPosition.x < quarterScreen {
            randomXVel = enemyXVelDict["farLeft"]!
        } else if randomPosition.x < halfScreen {
            randomXVel = enemyXVelDict["left"]!
        } else if randomPosition.x < threeQuarterScreen {
            randomXVel = enemyXVelDict["right"]!
        } else {
            randomXVel = enemyXVelDict["farRight"]!
        }
        
        let randomYVel = Int.random(in: yVel)
        
        enemy.physicsBody = SKPhysicsBody(circleOfRadius: CGFloat(enemyBodyRadius))
        enemy.physicsBody?.velocity = CGVector(dx: randomXVel * multiplier, dy: randomYVel * multiplier)
        enemy.physicsBody?.angularVelocity = randomAngularVel
        enemy.physicsBody?.collisionBitMask = 0
        
        if enemy.name == "fastEnemy"{
            enemy.scale(to: CGSize(width: 50, height: 50))
        }
        
        addChild(enemy)
        activeEnemies.append(enemy)
    }
    
    func subtractLife(){
        lives -= 1
        run(SKAction.playSoundFileNamed("wrong.caf", waitForCompletion: false))
        
        var life : SKSpriteNode
        
        if lives == 2 {
            life = livesImages[0]
        } else if lives == 1{
            life = livesImages[1]
        } else {
            life = livesImages[2]
            endGame(triggeredByBomb: false)
        }
        
        life.texture = SKTexture(imageNamed: "sliceLifeGone")
        life.xScale = 1.3
        life.yScale = 1.3
        
        life.run(SKAction.scale(to: 1, duration: 0.2))
    }
    
    override func update(_ currentTime: TimeInterval) {
        
        if activeEnemies.count > 0 {
            for (index, node) in activeEnemies.enumerated().reversed(){
                if node.position.y < -140 {
                    node.removeAllActions()
                    
                    if node.name == "enemy"{
                        node.name = ""
                        subtractLife()
                        
                        node.removeFromParent()
                        activeEnemies.remove(at: index)
                    } else if node.name == "bombContainer"{
                        node.name = ""
                        node.removeFromParent()
                        activeEnemies.remove(at: index)
                    } else if node.name == "fastEnemy"{
                        node.name = ""
                        node.removeFromParent()
                        activeEnemies.remove(at: index)
                    }
                }
            }
        } else {
            if !nextSequenceQueue{
                DispatchQueue.main.asyncAfter(deadline: .now() + popupTime){
                    [weak self] in
                    self?.tossEnemies()
                }
                nextSequenceQueue = true
            }
        }
        
        var bombCount = 0
        
        for node in activeEnemies{
            if node.name == "bombContainer"{
                bombCount += 1
                break
            }
        }
        if bombCount == 0 {
            // no bomb stop fuse effect
            bombSoundEffect?.stop()
            bombSoundEffect = nil
        }
        
        
    }
    
    func tossEnemies(){
        
        guard isGameEnded == false else {return}
        
        popupTime *= 0.991
        chainDelay *= 0.99
        physicsWorld.speed *= 1.02
        
        let sequenceType = sequence[sequencePosition]
        switch sequenceType {
        case .oneNoBomb:
            createEnemy(forceBomb: .never)
        case .one:
            createEnemy()
        case .twoWithOneBomb:
            createEnemy(forceBomb: .never)
            createEnemy(forceBomb: .always)
        case .two:
            createEnemy()
            createEnemy()
        case .three:
            createEnemy()
            createEnemy()
            createEnemy()
        case .four:
            createEnemy()
            createEnemy()
            createEnemy()
            createEnemy()
        case .chain:
            createEnemy()
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0)) {
                [weak self] in
                self?.createEnemy()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 2)) {
                [weak self] in
                self?.createEnemy()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 3)) {
                [weak self] in
                self?.createEnemy()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 4)) {
                [weak self] in
                self?.createEnemy()
            }
        case .fastChain:
            createEnemy()
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0)) {
                [weak self] in
                self?.createEnemy()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 2)) {
                [weak self] in
                self?.createEnemy()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 3)) {
                [weak self] in
                self?.createEnemy()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 4)) {
                [weak self] in
                self?.createEnemy()
            }
        }
        
        sequencePosition += 1
        nextSequenceQueue = false
    }
}
