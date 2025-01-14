import RxSwift
import StorageKit
import PinKit

class AppManager {
    private let accountManager: AccountManager
    private let walletManager: WalletManager
    private let adapterManager: AdapterManager
    private let pinKit: IPinKit
    private let keychainKit: IKeychainKit
    private let blurManager: BlurManager
    private let kitCleaner: KitCleaner
    private let debugBackgroundLogger: DebugLogger?
    private let appVersionManager: AppVersionManager
    private let rateAppManager: RateAppManager
    private let logRecordManager: LogRecordManager
    private let deepLinkManager: DeepLinkManager
    private let evmLabelManager: EvmLabelManager
    private let restoreFavoriteCoinWorker: RestoreFavoriteCoinWorker
    private let fillWalletInfoWorker: FillWalletInfoWorker

    private let didBecomeActiveSubject = PublishSubject<()>()
    private let willEnterForegroundSubject = PublishSubject<()>()

    init(accountManager: AccountManager, walletManager: WalletManager, adapterManager: AdapterManager, pinKit: IPinKit,
         keychainKit: IKeychainKit, blurManager: BlurManager,
         kitCleaner: KitCleaner, debugLogger: DebugLogger?,
         appVersionManager: AppVersionManager, rateAppManager: RateAppManager,
         logRecordManager: LogRecordManager,
         deepLinkManager: DeepLinkManager, evmLabelManager: EvmLabelManager,
         restoreFavoriteCoinWorker: RestoreFavoriteCoinWorker, fillWalletInfoWorker: FillWalletInfoWorker
    ) {
        self.accountManager = accountManager
        self.walletManager = walletManager
        self.adapterManager = adapterManager
        self.pinKit = pinKit
        self.keychainKit = keychainKit
        self.blurManager = blurManager
        self.kitCleaner = kitCleaner
        self.debugBackgroundLogger = debugLogger
        self.appVersionManager = appVersionManager
        self.rateAppManager = rateAppManager
        self.logRecordManager = logRecordManager
        self.deepLinkManager = deepLinkManager
        self.evmLabelManager = evmLabelManager
        self.restoreFavoriteCoinWorker = restoreFavoriteCoinWorker
        self.fillWalletInfoWorker = fillWalletInfoWorker
    }

}

extension AppManager {

    func didFinishLaunching() {
        debugBackgroundLogger?.logFinishLaunching()

        keychainKit.handleLaunch()
        accountManager.handleLaunch()
        walletManager.preloadWallets()
        pinKit.didFinishLaunching()
        kitCleaner.clear()

        appVersionManager.checkLatestVersion()
        rateAppManager.onLaunch()

        evmLabelManager.sync()

        try? restoreFavoriteCoinWorker.run()
        try? fillWalletInfoWorker.run()
    }

    func willResignActive() {
        blurManager.willResignActive()
        rateAppManager.onResignActive()
    }

    func didBecomeActive() {
        didBecomeActiveSubject.onNext(())

        blurManager.didBecomeActive()
        rateAppManager.onBecomeActive()
        logRecordManager.onBecomeActive()
    }

    func didEnterBackground() {
        debugBackgroundLogger?.logEnterBackground()

        pinKit.didEnterBackground()
    }

    func willEnterForeground() {
        accountManager.handleForeground()

        blurManager.willEnterForeground()
        debugBackgroundLogger?.logEnterForeground()
        willEnterForegroundSubject.onNext(())

        keychainKit.handleForeground()
        pinKit.willEnterForeground()
        adapterManager.refresh()
    }

    func willTerminate() {
        debugBackgroundLogger?.logTerminate()
    }

    func didReceive(url: URL) -> Bool {
        deepLinkManager.handle(url: url)
    }

}

extension AppManager: IAppManager {

    var didBecomeActiveObservable: Observable<()> {
        didBecomeActiveSubject.asObservable()
    }

    var willEnterForegroundObservable: Observable<()> {
        willEnterForegroundSubject.asObservable()
    }

}
