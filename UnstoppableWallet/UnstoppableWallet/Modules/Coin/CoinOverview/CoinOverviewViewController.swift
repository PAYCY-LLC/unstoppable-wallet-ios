import UIKit
import RxSwift
import ThemeKit
import SectionsTableView
import SnapKit
import HUD
import Chart
import ComponentKit
import Down

class CoinOverviewViewController: ThemeViewController {
    private let viewModel: CoinOverviewViewModel
    private let chartViewModel: CoinChartViewModel
    private let markdownParser: CoinPageMarkdownParser
    private var urlManager: UrlManager
    private let disposeBag = DisposeBag()

    private var viewItem: CoinOverviewViewModel.ViewItem?

    private let tableView = SectionsTableView(style: .grouped)
    private let coinInfoCell = A7Cell()
    private let spinner = HUDActivityView.create(with: .medium24)
    private let errorView = PlaceholderView()

    /* Chart section */
    private let chartCell: ChartCell
    private let chartRow: StaticRow

    /* Description */
    private let descriptionTextCell = ReadMoreTextCell()

    weak var parentNavigationController: UINavigationController?

    init(viewModel: CoinOverviewViewModel, chartViewModel: CoinChartViewModel, configuration: ChartConfiguration, markdownParser: CoinPageMarkdownParser, urlManager: UrlManager) {
        self.viewModel = viewModel
        self.chartViewModel = chartViewModel
        self.markdownParser = markdownParser
        self.urlManager = urlManager

        chartCell = ChartCell(viewModel: chartViewModel, touchDelegate: chartViewModel, viewOptions: ChartCell.coinChart, configuration: configuration)
        chartRow = StaticRow(
                cell: chartCell,
                id: "chartView",
                height: chartCell.cellHeight
        )

        super.init()

        hidesBottomBarWhenPushed = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        coinInfoCell.set(backgroundStyle: .transparent, isFirst: true, isLast: false)
        coinInfoCell.titleColor = .themeGray
        coinInfoCell.set(titleImageSize: .iconSize24)
        coinInfoCell.valueColor = .themeGray
        coinInfoCell.selectionStyle = .none

        let coinViewItem = viewModel.coinViewItem
        coinInfoCell.title = coinViewItem.name
        coinInfoCell.value = coinViewItem.marketCapRank
        coinInfoCell.setTitleImage(urlString: coinViewItem.imageUrl, placeholder: UIImage(named: coinViewItem.imagePlaceholderName))

        descriptionTextCell.set(backgroundStyle: .transparent, isFirst: true)
        descriptionTextCell.onChangeHeight = { [weak self] in
            self?.reloadTable()
        }

        let wrapperView = UIView()

        view.addSubview(wrapperView)
        wrapperView.snp.makeConstraints { maker in
            maker.leading.top.trailing.equalToSuperview()
            maker.bottom.equalTo(view.safeAreaLayoutGuide)
        }

        wrapperView.addSubview(spinner)
        spinner.snp.makeConstraints { maker in
            maker.center.equalToSuperview()
        }

        spinner.startAnimating()

        wrapperView.addSubview(errorView)
        errorView.snp.makeConstraints { maker in
            maker.edges.equalToSuperview()
        }

        errorView.configureSyncError(target: self, action: #selector(onRetry))

        view.addSubview(tableView)
        tableView.snp.makeConstraints { maker in
            maker.edges.equalToSuperview()
        }

        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear

        tableView.sectionDataSource = self

        tableView.showsVerticalScrollIndicator = false

        tableView.registerCell(forClass: A1Cell.self)
        tableView.registerCell(forClass: BCell.self)
        tableView.registerCell(forClass: D7Cell.self)
        tableView.registerCell(forClass: DB7Cell.self)
        tableView.registerCell(forClass: C85CellNew.self)
        tableView.registerCell(forClass: PerformanceTableViewCell.self)
        tableView.registerCell(forClass: BrandFooterCell.self)
        tableView.registerCell(forClass: TextCell.self)

        subscribe(disposeBag, viewModel.viewItemDriver) { [weak self] in self?.sync(viewItem: $0) }
        subscribe(disposeBag, viewModel.loadingDriver) { [weak self] loading in
            self?.spinner.isHidden = !loading
        }
        subscribe(disposeBag, viewModel.syncErrorDriver) { [weak self] visible in
            self?.errorView.isHidden = !visible
        }

        chartRow.onReady = { [weak chartCell] in chartCell?.onLoad() }

        viewModel.onLoad()
        chartViewModel.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        tableView.deselectCell(withCoordinator: transitionCoordinator, animated: animated)
    }

    @objc private func onRetry() {
        viewModel.onTapRetry()
        chartViewModel.retry()
    }

    private func sync(viewItem: CoinOverviewViewModel.ViewItem?) {
        self.viewItem = viewItem

        if viewItem != nil {
            tableView.isHidden = false
        } else {
            tableView.isHidden = true
        }

        tableView.reload()
    }

    private func reloadTable() {
        tableView.buildSections()

        tableView.beginUpdates()
        tableView.endUpdates()
    }

}

extension CoinOverviewViewController {

    private var coinInfoSection: SectionProtocol {
        Section(
                id: "coin-info",
                rows: [
                    StaticRow(
                            cell: coinInfoCell,
                            id: "coin-info",
                            height: .heightCell48
                    )
                ]
        )
    }

    private var chartSection: SectionProtocol {
        Section(
                id: "chart",
                rows: [chartRow]
        )
    }

    private func headerRow(title: String) -> RowProtocol {
        Row<BCell>(
                id: "header_cell_\(title)",
                hash: title,
                height: .heightCell48,
                bind: { cell, _ in
                    cell.set(backgroundStyle: .transparent)
                    cell.selectionStyle = .none
                    cell.title = title
                }
        )
    }

    private func descriptionSection(description: String) -> SectionProtocol {
        var rows: [RowProtocol] = [
            headerRow(title: "chart.about.header".localized)
        ]

        descriptionTextCell.contentText = try? markdownParser.attributedString(from: description)
        rows.append(
                StaticRow(
                        cell: descriptionTextCell,
                        id: "about_cell",
                        dynamicHeight: { [weak self] containerWidth in
                            self?.descriptionTextCell.cellHeight(containerWidth: containerWidth) ?? 0
                        }
                ))

        return Section(
                id: "description",
                headerState: .margin(height: .margin12),
                rows: rows
        )
    }

    private func linksSection(guideUrl: URL?, links: [CoinOverviewViewModel.LinkViewItem]) -> SectionProtocol {
        var guideRows = [RowProtocol]()

        if let guideUrl = guideUrl {
            let isLast = links.isEmpty

            let guideRow = Row<A1Cell>(
                    id: "guide",
                    height: .heightCell48,
                    bind: { cell, _ in
                        cell.set(backgroundStyle: .lawrence, isFirst: true, isLast: isLast)
                        cell.titleImage = UIImage(named: "academy_1_20")
                        cell.title = "coin_page.guide".localized
                    },
                    action: { [weak self] _ in
                        let module = MarkdownModule.viewController(url: guideUrl)
                        self?.parentNavigationController?.pushViewController(module, animated: true)
                    }
            )

            guideRows.append(guideRow)
        }

        return Section(
                id: "links",
                headerState: .margin(height: .margin12),
                rows: [headerRow(title: "coin_page.links".localized)] + guideRows + links.enumerated().map { index, link in
                    let isFirst = guideRows.isEmpty && index == 0
                    let isLast = index == links.count - 1

                    return Row<A1Cell>(
                            id: link.title,
                            height: .heightCell48,
                            autoDeselect: true,
                            bind: { cell, _ in
                                cell.set(backgroundStyle: .lawrence, isFirst: isFirst, isLast: isLast)
                                cell.titleImage = UIImage(named: link.iconName)
                                cell.title = link.title
                            },
                            action: { [weak self] _ in
                                self?.openLink(url: link.url)
                            }
                    )
                }
        )
    }

    private func openLink(url: String) {
        if url.hasPrefix("https://twitter.com/") {
            let account = url.stripping(prefix: "https://twitter.com/")

            if let appUrl = URL(string: "twitter://user?screen_name=\(account)"), UIApplication.shared.canOpenURL(appUrl) {
                UIApplication.shared.open(appUrl)
                return
            }
        }

        urlManager.open(url: url, from: parentNavigationController)
    }

    private func poweredBySection(text: String) -> SectionProtocol {
        Section(
                id: "powered-by",
                headerState: .margin(height: .margin32),
                rows: [
                    Row<BrandFooterCell>(
                            id: "powered-by",
                            dynamicHeight: { containerWidth in
                                BrandFooterCell.height(containerWidth: containerWidth, title: text)
                            },
                            bind: { cell, _ in
                                cell.title = text
                            }
                    )
                ]
        )
    }

    private func performanceSection(viewItems: [[CoinOverviewViewModel.PerformanceViewItem]]) -> SectionProtocol {
        Section(
                id: "return_of_investments_section",
                headerState: .margin(height: .margin12),
                rows: [
                    Row<PerformanceTableViewCell>(
                            id: "return_of_investments_cell",
                            dynamicHeight: { _ in
                                PerformanceTableViewCell.height(viewItems: viewItems)
                            },
                            bind: { cell, _ in
                                cell.bind(viewItems: viewItems)
                            }
                    )
                ]
        )
    }

    private func categoriesSection(categories: [String]) -> SectionProtocol {
        let text = categories.joined(separator: ", ")

        return Section(
                id: "categories",
                headerState: .margin(height: .margin12),
                rows: [
                    headerRow(title: "coin_page.category".localized),
                    Row<TextCell>(
                            id: "categories",
                            dynamicHeight: { width in
                                TextCell.height(containerWidth: width, text: text)
                            },
                            bind: { cell, _ in
                                cell.contentText = text
                            }
                    )
                ]
        )
    }

    private func contractsSection(contracts: [CoinOverviewViewModel.ContractViewItem]) -> SectionProtocol {
        Section(
                id: "contract-info",
                headerState: .margin(height: .margin12),
                rows: [headerRow(title: "coin_page.contracts".localized)] +
                        contracts.enumerated().map { index, contractViewItem in
                            Row<C85CellNew>(
                                    id: "contract-info",
                                    height: .heightCell48,
                                    bind: { cell, _ in
                                        cell.selectionStyle = .none
                                        cell.set(backgroundStyle: .lawrence, isFirst: index <= 0, isLast: index >= contracts.count - 1)

                                        cell.titleStyle = .subhead2Grey
                                        cell.title = contractViewItem.reference
                                        cell.titleImage = UIImage(named: contractViewItem.iconName)
                                        cell.firstImage = UIImage(named: "copy_20")
                                        cell.secondImage = UIImage(named: "globe_20")

                                        cell.leftAction = {
                                            UIPasteboard.general.setValue(contractViewItem.reference, forPasteboardType: "public.plain-text")
                                            HudHelper.instance.showSuccess(title: "alert.copied".localized)
                                        }

                                        cell.rightAction = { [weak self] in
                                            self?.urlManager.open(url: contractViewItem.explorerUrl, from: self?.parentNavigationController)
                                        }
                                    }
                            )
                        }
        )
    }

    private func marketRow(id: String, title: String, badge: String?, text: String, isFirst: Bool, isLast: Bool) -> RowProtocol {
        if let badge = badge {
            return Row<DB7Cell>(
                    id: id,
                    height: .heightCell48,
                    bind: { cell, _ in
                        cell.set(backgroundStyle: .lawrence, isFirst: isFirst, isLast: isLast)
                        cell.title = title
                        cell.titleBadgeText = badge
                        cell.value = text
                    }
            )
        } else {
            return Row<D7Cell>(
                    id: id,
                    height: .heightCell48,
                    bind: { cell, _ in
                        cell.set(backgroundStyle: .lawrence, isFirst: isFirst, isLast: isLast)
                        cell.title = title
                        cell.value = text
                    }
            )
        }
    }

    private func marketInfoSection(viewItem: CoinOverviewViewModel.ViewItem) -> SectionProtocol? {
        let datas = [
            viewItem.marketCap.map {
                (id: "market_cap", title: "coin_page.market_cap".localized, badge: viewItem.marketCapRank, text: $0)
            },
            viewItem.totalSupply.map {
                (id: "total_supply", title: "coin_page.total_supply".localized, badge: nil, text: $0)
            },
            viewItem.circulatingSupply.map {
                (id: "circulating_supply", title: "coin_page.circulating_supply".localized, badge: nil, text: $0)
            },
            viewItem.volume24h.map {
                (id: "volume24", title: "coin_page.trading_volume".localized, badge: nil, text: $0)
            },
            viewItem.dilutedMarketCap.map {
                (id: "diluted_m_cap", title: "coin_page.diluted_market_cap".localized, badge: nil, text: $0)
            },
            viewItem.tvl.map {
                (id: "tvl", title: "coin_page.tvl".localized, badge: nil, text: $0)
            },
            viewItem.genesisDate.map {
                (id: "genesis_date", title: "coin_page.genesis_date".localized, badge: nil, text: $0)
            }
        ].compactMap {
            $0
        }

        guard !datas.isEmpty else {
            return nil
        }

        let rows = datas.enumerated().map { index, tuple in
            marketRow(
                    id: tuple.id,
                    title: tuple.title,
                    badge: tuple.badge,
                    text: tuple.text,
                    isFirst: index == 0,
                    isLast: index == datas.count - 1
            )
        }


        return Section(
                id: "market_info_section",
                headerState: .margin(height: .margin12),
                rows: rows
        )
    }

}

extension CoinOverviewViewController: SectionsDataSource {

    public func buildSections() -> [SectionProtocol] {
        var sections = [SectionProtocol]()

        if let viewItem = viewItem {
            sections.append(coinInfoSection)
            sections.append(chartSection)

            if let marketInfoSection = marketInfoSection(viewItem: viewItem) {
                sections.append(marketInfoSection)
            }

            sections.append(performanceSection(viewItems: viewItem.performance))

            if let categories = viewItem.categories {
                sections.append(categoriesSection(categories: categories))
            }

            if let contracts = viewItem.contracts {
                sections.append(contractsSection(contracts: contracts))
            }

            if !viewItem.description.isEmpty {
                sections.append(descriptionSection(description: viewItem.description))
            }

            if viewItem.guideUrl != nil || !viewItem.links.isEmpty {
                sections.append(linksSection(guideUrl: viewItem.guideUrl, links: viewItem.links))
            }

            sections.append(poweredBySection(text: "Powered by CoinGecko API"))
        }

        return sections
    }

}
