import RxSwift

class TransactionSyncStateService {
    private var disposeBag = DisposeBag()

    private var adapterManager: TransactionAdapterManager
    private var adapters = [TransactionSource: ITransactionsAdapter]()
    private(set) var syncing: Bool = true {
        didSet {
            if syncing != oldValue {
                syncingSubject.onNext(syncing)
            }
        }
    }

    private var lastBlockInfoSubject = PublishSubject<(TransactionSource, LastBlockInfo)>()
    private var syncingSubject = PublishSubject<Bool>()

    init(adapterManager: TransactionAdapterManager) {
        self.adapterManager = adapterManager
    }

    func stateUpdated() {
        for adapter in adapters.values {
            switch adapter.transactionState {
            case .syncing, .searchingTxs:
                syncing = true
                return
            default: ()
            }
        }

        syncing = false
    }

}

extension TransactionSyncStateService {

    var lastBlockInfoObservable: Observable<(TransactionSource, LastBlockInfo)> {
        lastBlockInfoSubject.asObservable()
    }

    var syncingObservable: Observable<Bool> {
        syncingSubject.asObservable()
    }

    func lastBlockInfo(source: TransactionSource) -> LastBlockInfo? {
        adapters[source]?.lastBlockInfo
    }

    func set(sources: [TransactionSource]) {
        disposeBag = DisposeBag()
        adapters = [:]

        stateUpdated()

        for source in sources {
            if let adapter = adapterManager.adapter(for: source) {
                adapters[source] = adapter

                adapter.lastBlockUpdatedObservable
                        .subscribe(onNext: { [weak self] in
                            adapter.lastBlockInfo.flatMap {
                                self?.lastBlockInfoSubject.onNext((source, $0))
                            }
                        })
                        .disposed(by: disposeBag)

                adapter.transactionStateUpdatedObservable
                        .subscribe(onNext: { [weak self] in self?.stateUpdated() })
                        .disposed(by: disposeBag)
            }
        }
    }

}
