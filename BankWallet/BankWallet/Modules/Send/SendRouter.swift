import UIKit

class SendRouter {
    weak var viewController: UINavigationController?
}

extension SendRouter: ISendRouter {

    func showConfirmation(item: SendConfirmationViewItem, delegate: ISendConfirmationDelegate) {
        let confirmationController = SendConfirmationRouter.module(item: item, delegate: delegate)
        viewController?.pushViewController(confirmationController, animated: true)
    }

    func scanQrCode(delegate: IScanQrCodeDelegate) {
        let scanController = ScanQRController(delegate: delegate)
        viewController?.present(scanController, animated: true)
    }

    func dismiss() {
        viewController?.dismiss(animated: true)
    }

}

extension SendRouter {

    static func module(coinCode: CoinCode) -> UIViewController? {
        guard let wallet = App.shared.walletManager.wallets.first(where: { $0.coin.code == coinCode }),
              let adapter = App.shared.adapterManager.adapter(for: wallet) else {
            return nil
        }

        let factory = SendConfirmationItemFactory()

        let router = SendRouter()
        let interactor = SendInteractor(pasteboardManager: App.shared.pasteboardManager, wallet: wallet, adapter: adapter, backgroundManager: App.shared.backgroundManager)

        var views = [UIView]()
        let viewController: UIViewController & ISendView
        if adapter is EosAdapter {
            let (amountView, amountModule) = SendAmountRouter.module(coinCode: coinCode, decimal: adapter.decimal)
            let (addressView, addressModule) = SendAddressRouter.module(canEdit: true, placeholder: "send.account_placeholder")
            views.append(contentsOf: [amountView, addressView])

            let presenter = EOSSendPresenter(interactor: interactor, router: router, factory: factory, amountModule: amountModule, addressModule: addressModule)
            viewController = SendViewController(delegate: presenter, views: views)

            amountModule.delegate = presenter
            addressModule.delegate = presenter

            interactor.delegate = presenter
            presenter.view = viewController
        } else if adapter is BinanceAdapter {
            let feeCoinCode = adapter.feeCoinCode ?? wallet.coin.code

            let (amountView, amountModule) = SendAmountRouter.module(coinCode: coinCode, decimal: adapter.decimal)
            let (addressView, addressModule) = SendAddressRouter.module()
            let (feeView, feeModule) = SendFeeRouter.module(feeCoinCode: feeCoinCode, coinProtocol: "BEP2", baseCoinName: "Binance", decimal: adapter.decimal, feeAdjustable: false)
            views.append(contentsOf: [amountView, addressView, feeView])

            let presenter = SendPresenter(interactor: interactor, router: router, factory: factory, showMemo: true, amountModule: amountModule, addressModule: addressModule, feeModule: feeModule)
            viewController = SendViewController(delegate: presenter, views: views)

            amountModule.delegate = presenter
            addressModule.delegate = presenter
            feeModule.delegate = presenter

            interactor.delegate = presenter
            presenter.view = viewController
        } else {
            let feeCoinCode = adapter.feeCoinCode ?? wallet.coin.code

            let (amountView, amountModule) = SendAmountRouter.module(coinCode: coinCode, decimal: adapter.decimal)
            let (addressView, addressModule) = SendAddressRouter.module()
            let (feeView, feeModule) = SendFeeRouter.module(feeCoinCode: feeCoinCode, decimal: adapter.decimal)
            views.append(contentsOf: [amountView, addressView, feeView])

            let presenter = SendPresenter(interactor: interactor, router: router, factory: factory, amountModule: amountModule, addressModule: addressModule, feeModule: feeModule)
            viewController = SendViewController(delegate: presenter, views: views)

            amountModule.delegate = presenter
            addressModule.delegate = presenter
            feeModule.delegate = presenter

            interactor.delegate = presenter
            presenter.view = viewController
        }

        let navigationController = WalletNavigationController(rootViewController: viewController)
        router.viewController = navigationController
        return navigationController
    }

}
