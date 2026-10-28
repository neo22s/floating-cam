// Floating Camera — MIT License. See LICENSE.

import AVFoundation
import CoreMedia
import Foundation

struct CameraDeviceInfo {
    let id: String
    let name: String
    let aspectRatio: CGSize
}

struct CameraSessionInfo {
    let session: AVCaptureSession
    let device: CameraDeviceInfo
    let resolution: CameraResolution
    let frameRate: FrameRate
}

enum CameraError: LocalizedError {
    case permissionDenied
    case noCamera
    case inputFailed
    case cannotAddInput
    case deviceNotFound
    case sessionNotReady

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return L10n.s(
                "Camera access is required. Enable it in System Settings → Privacy & Security → Camera.",
                "Se requiere acceso a la cámara. Actívalo en Ajustes del Sistema → Privacidad y seguridad → Cámara."
            )
        case .noCamera:
            return L10n.s(
                "No camera was found on this Mac.",
                "No se encontró ninguna cámara en este Mac."
            )
        case .inputFailed:
            return L10n.s(
                "The selected camera could not be opened.",
                "No se pudo abrir la cámara seleccionada."
            )
        case .cannotAddInput:
            return L10n.s(
                "The camera could not be added to the capture session.",
                "No se pudo añadir la cámara a la sesión de captura."
            )
        case .deviceNotFound:
            return L10n.s(
                "The selected camera is no longer available.",
                "La cámara seleccionada ya no está disponible."
            )
        case .sessionNotReady:
            return L10n.s(
                "The camera is not ready yet.",
                "La cámara aún no está lista."
            )
        }
    }
}

final class CameraManager {
    private let queue = DispatchQueue(label: "com.floatingcamera.capture", qos: .userInitiated)
    private let stateLock = NSLock()
    private var session: AVCaptureSession?
    private var input: AVCaptureDeviceInput?
    private var currentResolution: CameraResolution = .p720
    private var currentFrameRate: FrameRate = .fps30
    private var shouldRun = false
    private var _activeDeviceID: String?
    private var observers: [NSObjectProtocol] = []

    private(set) var devices: [CameraDeviceInfo] = []

    var onDevicesChanged: (([CameraDeviceInfo]) -> Void)?

    var activeDeviceID: String? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _activeDeviceID
    }

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSNotification.Name.AVCaptureDeviceWasConnected,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshDevices()
        })
        observers.append(center.addObserver(
            forName: NSNotification.Name.AVCaptureDeviceWasDisconnected,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshDevices()
        })
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func start(
        preferredCameraID: String?,
        resolution: CameraResolution,
        frameRate: FrameRate,
        completion: @escaping (Result<CameraSessionInfo, Error>) -> Void
    ) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart(
                preferredCameraID: preferredCameraID,
                resolution: resolution,
                frameRate: frameRate,
                completion: completion
            )
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.configureAndStart(
                        preferredCameraID: preferredCameraID,
                        resolution: resolution,
                        frameRate: frameRate,
                        completion: completion
                    )
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(CameraError.permissionDenied))
                    }
                }
            }
        default:
            DispatchQueue.main.async {
                completion(.failure(CameraError.permissionDenied))
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.shouldRun = false
            guard let session = self.session, session.isRunning else { return }
            session.stopRunning()
        }
    }

    func refreshDevices() {
        queue.async { [weak self] in
            guard let self else { return }
            let discovered = Self.discoverDevices()
            let infos = discovered.map(Self.info)
            DispatchQueue.main.async {
                self.devices = infos
                self.onDevicesChanged?(infos)
            }
        }
    }

    func switchCamera(
        to id: String,
        completion: @escaping (Result<CameraSessionInfo, Error>) -> Void
    ) {
        queue.async { [weak self] in
            guard let self, let session = self.session else {
                DispatchQueue.main.async {
                    completion(.failure(CameraError.sessionNotReady))
                }
                return
            }

            let discovered = Self.discoverDevices()
            guard let device = discovered.first(where: { $0.uniqueID == id }) else {
                DispatchQueue.main.async {
                    completion(.failure(CameraError.deviceNotFound))
                }
                return
            }

            do {
                let newInput = try AVCaptureDeviceInput(device: device)
                session.beginConfiguration()
                let oldInputs = session.inputs
                oldInputs.forEach(session.removeInput)
                guard session.canAddInput(newInput) else {
                    oldInputs.forEach { if session.canAddInput($0) { session.addInput($0) } }
                    session.commitConfiguration()
                    DispatchQueue.main.async {
                        completion(.failure(CameraError.cannotAddInput))
                    }
                    return
                }

                session.addInput(newInput)
                self.input = newInput
                let actualResolution = self.applyResolution(self.currentResolution, to: session)
                self.currentResolution = actualResolution
                self.setActiveDeviceID(device.uniqueID)
                session.commitConfiguration()

                self.currentFrameRate = self.applyFrameRate(self.currentFrameRate, to: device)
                let info = Self.info(for: device)
                let infos = discovered.map(Self.info)
                let result = CameraSessionInfo(
                    session: session,
                    device: info,
                    resolution: actualResolution,
                    frameRate: self.currentFrameRate
                )

                DispatchQueue.main.async {
                    self.devices = infos
                    self.onDevicesChanged?(infos)
                    completion(.success(result))
                }

                if self.shouldRun, !session.isRunning {
                    session.startRunning()
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(CameraError.inputFailed))
                }
            }
        }
    }

    func setResolution(
        _ resolution: CameraResolution,
        completion: @escaping (Result<CameraSessionInfo, Error>) -> Void
    ) {
        queue.async { [weak self] in
            guard let self, let session = self.session, let device = self.input?.device else {
                DispatchQueue.main.async {
                    completion(.failure(CameraError.sessionNotReady))
                }
                return
            }

            session.beginConfiguration()
            let actualResolution = self.applyResolution(resolution, to: session)
            session.commitConfiguration()
            self.currentResolution = actualResolution
            self.currentFrameRate = self.applyFrameRate(self.currentFrameRate, to: device)

            let info = Self.info(for: device)
            let result = CameraSessionInfo(
                session: session,
                device: info,
                resolution: actualResolution,
                frameRate: self.currentFrameRate
            )
            DispatchQueue.main.async {
                completion(.success(result))
            }
        }
    }

    func setFrameRate(
        _ frameRate: FrameRate,
        completion: @escaping (Result<CameraSessionInfo, Error>) -> Void
    ) {
        queue.async { [weak self] in
            guard let self, let device = self.input?.device, let session = self.session else {
                DispatchQueue.main.async {
                    completion(.failure(CameraError.sessionNotReady))
                }
                return
            }

            self.currentFrameRate = self.applyFrameRate(frameRate, to: device)
            let info = Self.info(for: device)
            let result = CameraSessionInfo(
                session: session,
                device: info,
                resolution: self.currentResolution,
                frameRate: self.currentFrameRate
            )
            DispatchQueue.main.async {
                completion(.success(result))
            }
        }
    }

    func shutdown() {
        queue.sync {
            shouldRun = false
            if let session, session.isRunning {
                session.stopRunning()
            }
        }
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
    }

    private func configureAndStart(
        preferredCameraID: String?,
        resolution: CameraResolution,
        frameRate: FrameRate,
        completion: @escaping (Result<CameraSessionInfo, Error>) -> Void
    ) {
        queue.async { [weak self] in
            guard let self else { return }

            let session = self.session ?? AVCaptureSession()
            self.session = session
            self.shouldRun = true

            let discovered = Self.discoverDevices()
            guard let device = Self.pickDevice(preferredID: preferredCameraID, from: discovered) else {
                DispatchQueue.main.async {
                    self.devices = []
                    self.onDevicesChanged?([])
                    completion(.failure(CameraError.noCamera))
                }
                return
            }

            let reuseInput = self.input?.device.uniqueID == device.uniqueID
                && self.input.map { current in session.inputs.contains { $0 === current } } == true

            session.beginConfiguration()

            if !reuseInput {
                do {
                    let newInput = try AVCaptureDeviceInput(device: device)
                    if let oldInput = self.input {
                        session.removeInput(oldInput)
                    }
                    guard session.canAddInput(newInput) else {
                        if let oldInput = self.input, session.canAddInput(oldInput) {
                            session.addInput(oldInput)
                        }
                        session.commitConfiguration()
                        DispatchQueue.main.async {
                            completion(.failure(CameraError.cannotAddInput))
                        }
                        return
                    }
                    session.addInput(newInput)
                    self.input = newInput
                } catch {
                    session.commitConfiguration()
                    DispatchQueue.main.async {
                        completion(.failure(CameraError.inputFailed))
                    }
                    return
                }
            }

            let actualResolution = self.applyResolution(resolution, to: session)
            self.currentResolution = actualResolution
            self.setActiveDeviceID(device.uniqueID)
            session.commitConfiguration()

            self.currentFrameRate = self.applyFrameRate(frameRate, to: device)
            let info = Self.info(for: device)
            let infos = discovered.map(Self.info)
            let result = CameraSessionInfo(
                session: session,
                device: info,
                resolution: actualResolution,
                frameRate: self.currentFrameRate
            )

            DispatchQueue.main.async {
                self.devices = infos
                self.onDevicesChanged?(infos)
                completion(.success(result))
            }

            if self.shouldRun, !session.isRunning {
                session.startRunning()
                self.currentFrameRate = self.applyFrameRate(self.currentFrameRate, to: device)
            }
        }
    }

    private func applyResolution(
        _ resolution: CameraResolution,
        to session: AVCaptureSession
    ) -> CameraResolution {
        if session.canSetSessionPreset(resolution.preset) {
            session.sessionPreset = resolution.preset
            return resolution
        }

        for fallback in [CameraResolution.p720, .p480] where fallback != resolution {
            if session.canSetSessionPreset(fallback.preset) {
                session.sessionPreset = fallback.preset
                return fallback
            }
        }

        return CameraResolution.closest(to: session.sessionPreset) ?? resolution
    }

    private func applyFrameRate(_ frameRate: FrameRate, to device: AVCaptureDevice) -> FrameRate {
        let ranges = device.activeFormat.videoSupportedFrameRateRanges.map {
            $0.minFrameRate...$0.maxFrameRate
        }
        guard let actual = FrameRate.best(requested: frameRate, within: ranges) else {
            return frameRate
        }

        do {
            try device.lockForConfiguration()
            let duration = CMTime(value: 1, timescale: CMTimeScale(actual.rawValue))
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
            device.unlockForConfiguration()
            return actual
        } catch {
            return frameRate
        }
    }

    private func setActiveDeviceID(_ id: String?) {
        stateLock.lock()
        _activeDeviceID = id
        stateLock.unlock()
    }

    private static func pickDevice(
        preferredID: String?,
        from devices: [AVCaptureDevice]
    ) -> AVCaptureDevice? {
        if let preferredID, let preferred = devices.first(where: { $0.uniqueID == preferredID }) {
            return preferred
        }
        if let systemDefault = AVCaptureDevice.default(for: .video),
           let match = devices.first(where: { $0.uniqueID == systemDefault.uniqueID }) {
            return match
        }
        return devices.first
    }

    private static func discoverDevices() -> [AVCaptureDevice] {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .external,
            .continuityCamera,
            .deskViewCamera
        ]
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: .unspecified
        ).devices.sorted {
            let left = priority($0)
            let right = priority($1)
            if left != right { return left < right }
            return $0.localizedName.localizedCaseInsensitiveCompare($1.localizedName) == .orderedAscending
        }
    }

    private static func priority(_ device: AVCaptureDevice) -> Int {
        switch device.deviceType {
        case .builtInWideAngleCamera: return 0
        case .external: return 1
        case .continuityCamera: return 2
        case .deskViewCamera: return 3
        default: return 4
        }
    }

    private static func info(for device: AVCaptureDevice) -> CameraDeviceInfo {
        let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        return CameraDeviceInfo(
            id: device.uniqueID,
            name: device.localizedName,
            aspectRatio: CGSize(
                width: dimensions.width > 0 ? CGFloat(dimensions.width) : 16,
                height: dimensions.height > 0 ? CGFloat(dimensions.height) : 9
            )
        )
    }
}
