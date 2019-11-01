import RxSwift
import XRatesKit

class RateManager {
    private let disposeBag = DisposeBag()

    private let walletManager: IWalletManager
    private let currencyManager: ICurrencyManager

    private let kit: XRatesKit

    init(walletManager: IWalletManager, currencyManager: ICurrencyManager) {
        self.walletManager = walletManager
        self.currencyManager = currencyManager

        kit = XRatesKit.instance(currencyCode: currencyManager.baseCurrency.code, marketInfoExpirationInterval: 10 * 60)

        walletManager.walletsUpdatedObservable
                .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe(onNext: { [weak self] wallets in
                    self?.onUpdate(wallets: wallets)
                })
                .disposed(by: disposeBag)

        currencyManager.baseCurrencyUpdatedSignal
                .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe(onNext: { [weak self] in
                    self?.onBaseCurrencyUpdated()
                })
                .disposed(by: disposeBag)
    }

    private func onUpdate(wallets: [Wallet]) {
        kit.set(coinCodes: wallets.map { $0.coin.code })
    }

    private func onBaseCurrencyUpdated() {
        kit.set(currencyCode: currencyManager.baseCurrency.code)
    }

}

extension RateManager: IRateManager {

    func refresh() {
        kit.refresh()
    }

    func marketInfo(coinCode: String, currencyCode: String) -> MarketInfo? {
        kit.marketInfo(coinCode: coinCode, currencyCode: currencyCode)
    }

    func marketInfoObservable(coinCode: String, currencyCode: String) -> Observable<MarketInfo> {
        kit.marketInfoObservable(coinCode: coinCode, currencyCode: currencyCode)
    }

    func marketInfosObservable(currencyCode: String) -> Observable<[String: MarketInfo]> {
        kit.marketInfosObservable(currencyCode: currencyCode)
    }

    func historicalRate(coinCode: String, currencyCode: String, timestamp: TimeInterval) -> Single<Decimal> {
        kit.historicalRate(coinCode: coinCode, currencyCode: currencyCode, timestamp: timestamp)
    }

    func chartInfo(coinCode: String, currencyCode: String, chartType: ChartType) -> ChartInfo? {
        kit.chartInfo(coinCode: coinCode, currencyCode: currencyCode, chartType: chartType)
    }

    func chartInfoObservable(coinCode: String, currencyCode: String, chartType: ChartType) -> Observable<ChartInfo> {
        kit.chartInfoObservable(coinCode: coinCode, currencyCode: currencyCode, chartType: chartType)
    }

}