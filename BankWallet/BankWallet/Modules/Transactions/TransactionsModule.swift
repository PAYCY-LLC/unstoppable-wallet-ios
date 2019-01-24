enum TransactionStatus {
    case pending
    case processing(confirmations: Int)
    case completed
}

extension TransactionStatus: Equatable {

    public static func ==(lhs: TransactionStatus, rhs: TransactionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .pending): return true
        case (let .processing(lhsConfirmations), let .processing(rhsConfirmations)): return lhsConfirmations == rhsConfirmations
        case (.completed, .completed): return true
        default: return false
        }
    }

}

protocol ITransactionsView: class {
    func show(filters: [CoinCode?])
    func reload()
}

protocol ITransactionsViewDelegate {
    func viewDidLoad()
    func onFilterSelect(coinCode: CoinCode?)

    var itemsCount: Int { get }
    func item(forIndex index: Int) -> TransactionViewItem
    func onBottomReached()

    func onTransactionItemClick(index: Int)
}

protocol ITransactionsInteractor {
    func initialFetch()
    func fetchLastBlockHeights()

    func fetchRecords(fetchDataList: [FetchData])
    func set(selectedCoinCodes: [CoinCode])

    func fetchRates(timestampsData: [CoinCode: [Double]])
}

protocol ITransactionsInteractorDelegate: class {
    func onUpdate(selectedCoinCodes: [CoinCode])
    func onUpdate(coinCodes: [CoinCode])
    func onUpdateBaseCurrency()

    func onUpdate(lastBlockHeight: Int, coinCode: CoinCode)
    func onUpdate(threshold: Int, coinCode: CoinCode)

    func didUpdate(records: [TransactionRecord], coinCode: CoinCode)

    func didFetch(rateValue: Double, coinCode: CoinCode, currency: Currency, timestamp: Double)
    func didFetch(recordsData: [CoinCode: [TransactionRecord]])
}

protocol ITransactionsRouter {
    func openTransactionInfo(viewItem: TransactionViewItem)
}

protocol ITransactionLoaderDelegate: class {
    func fetchRecords(fetchDataList: [FetchData])
    func didChangeData()
}

protocol ITransactionViewItemFactory {
    func viewItem(fromItem item: TransactionItem, lastBlockHeight: Int?, threshold: Int?, rate: CurrencyValue?) -> TransactionViewItem
}

struct FetchData {
    let coinCode: CoinCode
    let hashFrom: String?
    let limit: Int
}
