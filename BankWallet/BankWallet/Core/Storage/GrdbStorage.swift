import RxSwift
import GRDB
import RxGRDB

class GrdbStorage {
    private let dbPool: DatabasePool

    init() {
        let databaseURL = try! FileManager.default
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("bank.sqlite")

        dbPool = try! DatabasePool(path: databaseURL.path)

        try! migrator.migrate(dbPool)
    }

    var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("createRate") { db in
            try db.create(table: Rate.databaseTableName) { t in
                t.column(Rate.Columns.coinCode.name, .text).notNull()
                t.column(Rate.Columns.currencyCode.name, .text).notNull()
                t.column(Rate.Columns.value.name, .text).notNull()
                t.column(Rate.Columns.isLatest.name, .boolean).notNull()

                t.primaryKey([
                    Rate.Columns.coinCode.name,
                    Rate.Columns.currencyCode.name,
                    Rate.Columns.isLatest.name
                ], onConflict: .replace)
            }
        }

        migrator.registerMigration("createEnabledWalletsTable") { db in
            try db.create(table: EnabledWallet.databaseTableName) { t in
                t.column(EnabledWallet.Columns.coinCode.name, .text).notNull()
                t.column(EnabledWallet.Columns.accountId.name, .text).notNull()
                t.column(EnabledWallet.Columns.syncMode.name, .text)
                t.column(EnabledWallet.Columns.walletOrder.name, .integer).notNull()

                t.primaryKey([EnabledWallet.Columns.coinCode.name, EnabledWallet.Columns.accountId.name], onConflict: .replace)
            }

            // transfer data from old "enabled_coins" table

            guard try db.tableExists("enabled_coins") else {
                return
            }

            let accountId = "" // todo
            let syncMode = (UserDefaults.standard.value(forKey: "sync_mode_key") as? String) ?? "fast"
            try db.execute(sql: """
                                INSERT INTO \(EnabledWallet.databaseTableName)(`\(EnabledWallet.Columns.coinCode.name)`, `\(EnabledWallet.Columns.accountId.name)`, `\(EnabledWallet.Columns.syncMode.name)`, `\(EnabledWallet.Columns.walletOrder.name)`) 
                                SELECT `coinCode`, '\(accountId)', '\(syncMode)', `coinOrder` FROM enabled_coins
                                """)
            try db.drop(table: "enabled_coins")
        }

        migrator.registerMigration("timestampToDateRates") { db in
            try db.drop(table: Rate.databaseTableName)
            try db.create(table: Rate.databaseTableName) { t in
                t.column(Rate.Columns.coinCode.name, .text).notNull()
                t.column(Rate.Columns.currencyCode.name, .text).notNull()
                t.column(Rate.Columns.value.name, .text).notNull()
                t.column(Rate.Columns.date.name, .double).notNull()
                t.column(Rate.Columns.isLatest.name, .boolean).notNull()

                t.primaryKey([
                    Rate.Columns.coinCode.name,
                    Rate.Columns.currencyCode.name,
                    Rate.Columns.date.name,
                    Rate.Columns.isLatest.name
                ], onConflict: .replace)
            }
        }

        migrator.registerMigration("createAccountsTable") { db in
            try db.create(table: AccountRecord.databaseTableName) { t in
                t.column(AccountRecord.Columns.id.name, .text).notNull()
                t.column(AccountRecord.Columns.name.name, .text).notNull()
                t.column(AccountRecord.Columns.type.name, .integer).notNull()
                t.column(AccountRecord.Columns.backedUp.name, .boolean).notNull()
                t.column(AccountRecord.Columns.defaultSyncMode.name, .text)
                t.column(AccountRecord.Columns.words.name, .blob)
                t.column(AccountRecord.Columns.derivation.name, .integer)
                t.column(AccountRecord.Columns.salt.name, .blob)
                t.column(AccountRecord.Columns.data.name, .blob)
                t.column(AccountRecord.Columns.eosAccount.name, .blob)

                t.primaryKey([
                    AccountRecord.Columns.id.name
                ], onConflict: .replace)
            }
        }

        return migrator
    }

}

extension GrdbStorage: IRateStorage {

    func nonExpiredLatestRateObservable(forCoinCode coinCode: CoinCode, currencyCode: String) -> Observable<Rate?> {
        return latestRateObservable(forCoinCode: coinCode, currencyCode: currencyCode)
                .flatMap { rate -> Observable<Rate?> in
                    guard !rate.expired else {
                        return Observable.just(nil)
                    }
                    return Observable.just(rate)
                }
    }

    func latestRateObservable(forCoinCode coinCode: CoinCode, currencyCode: String) -> Observable<Rate> {
        let request = Rate.filter(Rate.Columns.coinCode == coinCode && Rate.Columns.currencyCode == currencyCode && Rate.Columns.isLatest == true)
        return request.rx.fetchOne(in: dbPool)
                .flatMap { $0.map(Observable.just) ?? Observable.empty() }
    }

    func timestampRateObservable(coinCode: CoinCode, currencyCode: String, date: Date) -> Observable<Rate?> {
        let request = Rate.filter(Rate.Columns.coinCode == coinCode && Rate.Columns.currencyCode == currencyCode && Rate.Columns.date == date && Rate.Columns.isLatest == false)
        return request.rx.fetchOne(in: dbPool)
    }

    func zeroValueTimestampRatesObservable(currencyCode: String) -> Observable<[Rate]> {
        let request = Rate.filter(Rate.Columns.currencyCode == currencyCode && Rate.Columns.value == 0 && Rate.Columns.isLatest == false)
        return request.rx.fetchAll(in: dbPool)
    }

    func save(latestRate: Rate) {
        _ = try? dbPool.write { db in
            try Rate.filter(Rate.Columns.coinCode == latestRate.coinCode && Rate.Columns.currencyCode == latestRate.currencyCode && Rate.Columns.isLatest == true).deleteAll(db)
            try latestRate.insert(db)
        }
    }

    func save(rate: Rate) {
        _ = try? dbPool.write { db in
            try rate.insert(db)
        }
    }

    func clearRates() {
        _ = try? dbPool.write { db in
            try Rate.deleteAll(db)
        }
    }

}

extension GrdbStorage: IEnabledWalletStorage {

    var enabledWallets: [EnabledWallet] {
        return try! dbPool.read { db in
            try EnabledWallet.order(EnabledWallet.Columns.walletOrder).fetchAll(db)
        }
    }

    func save(enabledWallets: [EnabledWallet]) {
        _ = try! dbPool.write { db in
            try EnabledWallet.deleteAll(db)

            for enabledWallet in enabledWallets {
                try enabledWallet.insert(db)
            }
        }
    }

    func clearEnabledWallets() {
        _ = try! dbPool.write { db in
            try EnabledWallet.deleteAll(db)
        }
    }

}

extension GrdbStorage: IAccountStorage {

    var all: [Account] {
        return try! dbPool.read { db in
            try AccountRecord.fetchAll(db).map { try $0.getAccount() }
        }
    }

    func save(account: Account) {
        let accountRecord = try? dbPool.read { db in
            try AccountRecord.filter(AccountRecord.Columns.id == account.id).fetchOne(db)
        }
        accountRecord?.update(with: account)
        _ = try? dbPool.write { db in
            try (accountRecord ?? AccountRecord(account: account)).insert(db)
        }
    }

    func delete(id: String) {
        _ = try? dbPool.write { db in
            try AccountRecord.filter(AccountRecord.Columns.id == id).deleteAll(db)
        }
    }

    func setIsBackedUp(id: String) {
        _ = try? dbPool.write { db in
            let account = try AccountRecord.filter(AccountRecord.Columns.id == id).fetchOne(db)
            account?.backedUp = true
            try account?.insert(db)
        }
    }

}
