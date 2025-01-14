import UIKit
import RxSwift
import ThemeKit
import SectionsTableView
import SnapKit
import HUD
import Chart
import ComponentKit

class MetricChartViewController: ThemeActionSheetController {
    private let viewModel: MetricChartViewModel
    private let disposeBag = DisposeBag()

    private let titleView = BottomSheetTitleView()
    private let tableView = SelfSizedSectionsTableView(style: .grouped)
    private let poweredByLabel = UILabel()

    /* Chart section */
    private let chartCell: ChartCell
    private let chartRow: StaticRow

    init(viewModel: MetricChartViewModel, configuration: ChartConfiguration) {
        self.viewModel = viewModel

        chartCell = ChartCell(viewModel: viewModel, touchDelegate: viewModel, viewOptions: ChartCell.metricChart, configuration: configuration)

        chartRow = StaticRow(
                cell: chartCell,
                id: "chartView",
                height: chartCell.cellHeight
        )

        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(titleView)
        titleView.snp.makeConstraints { maker in
            maker.leading.top.trailing.equalToSuperview()
        }

        titleView.bind(
                title: viewModel.title,
                subtitle: "market.global.subtitle".localized,
                image: UIImage(named: "chart_2_24"),
                tintColor: .themeJacob
        )
        titleView.onTapClose = { [weak self] in
            self?.dismiss(animated: true)
        }

        view.addSubview(tableView)
        tableView.snp.makeConstraints { maker in
            maker.leading.trailing.equalToSuperview()
            maker.top.equalTo(titleView.snp.bottom)
        }

        title = viewModel.title

        tableView.sectionDataSource = self

        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear

        tableView.registerCell(forClass: G14Cell.self)
        tableView.registerCell(forClass: SpinnerCell.self)
        tableView.registerCell(forClass: ErrorCell.self)
        tableView.registerCell(forClass: TextCell.self)
        tableView.registerHeaderFooter(forClass: TopDescriptionHeaderFooterView.self)

        view.addSubview(poweredByLabel)
        poweredByLabel.snp.makeConstraints { maker in
            maker.leading.trailing.equalToSuperview().inset(CGFloat.margin24)
            maker.top.equalTo(tableView.snp.bottom)
            maker.bottom.equalToSuperview().inset(CGFloat.margin12 + CGFloat.margin16)
        }

        poweredByLabel.textAlignment = .center
        poweredByLabel.textColor = .themeGray
        poweredByLabel.font = .caption
        poweredByLabel.text = "Powered By \(viewModel.poweredBy)"

        chartRow.onReady = { [weak chartCell] in chartCell?.onLoad() }

        tableView.buildSections()
        viewModel.viewDidLoad()
    }

    private func reloadTable() {
        tableView.buildSections()

        tableView.beginUpdates()
        tableView.endUpdates()
    }

}

extension MetricChartViewController {

    private var chartSection: SectionProtocol {
        let description = viewModel.description
        let footerState: ViewState<TopDescriptionHeaderFooterView> = .cellType(hash: "bottom_description", binder: { view in
            view.bind(text: description)
        }, dynamicHeight: { [unowned self] _ in
            TopDescriptionHeaderFooterView.height(containerWidth: tableView.bounds.width, text: description ?? "")
        })

        return Section(
                id: "chart",
                footerState: footerState,
                rows: [chartRow]
        )
    }

}

extension MetricChartViewController: SectionsDataSource {

    public func buildSections() -> [SectionProtocol] {
        [chartSection]
    }

}
