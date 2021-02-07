//
//  ViewController.swift
//  RxDataSourcesSample
//
//  Created by Kohei Hayashi on 2021/02/06.
//

import UIKit
import RxSwift
import RxCocoa
import RxDataSources

// MARK: - SectionInfo
enum SectionItem {
    case stringSection(StringSectionRowItem)
    case intSection(IntSectionRowItem)
}

enum StringSectionRowItem: String {
    case first
    case second
    case third
}

enum IntSectionRowItem: Int {
    case first = 1
    case second = 2
    case third = 3
}
// MARK: - SectionModel
struct SectionModel: SectionModelType {
    typealias Item = SectionItem

    var title: String
    var items: [SectionItem]

    init(original: SectionModel, items: [Item]) {
        self = original
        self.items = items
    }

    init(title: String, items: [Item]) {
        self.title = title
        self.items = items
    }
}
// MARK: - ViewController
class ViewController: UIViewController {
    private let viewModel = ViewModel()
    private let tableView = UITableView()
    private let refreshControl = UIRefreshControl()
    private let dataSource = RxTableViewSectionedReloadDataSource<SectionModel>(
        configureCell: { _, tableView, indexPath, item in
            switch item {
            case .stringSection(let text):
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "cell") else { fatalError() }
                cell.textLabel?.text = text.rawValue
                return cell
            case .intSection(let number):
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "cell") else { fatalError() }
                cell.textLabel?.text = "\(number.rawValue)"
                return cell
            }
        }, titleForHeaderInSection: { dataSource, section in
            dataSource.sectionModels[section].title
        }
    )
    private let refreshRelay = PublishRelay<Void>()
    private let disposeBag = DisposeBag()

    override func loadView() {
        super.loadView()
        view.backgroundColor = .systemBackground
        tableView.refreshControl = refreshControl
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.tableFooterView = UIView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        refreshControl.addTarget(self, action: #selector(reloadTableView), for: .valueChanged)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let viewDidLoadRelay = PublishRelay<Void>()

        let (sectionInfo, didChangeSectionInfo) = viewModel.observeSectionInfo(viewDidLoad: viewDidLoadRelay,
                                                                               refresh: refreshRelay)
        sectionInfo
            .drive(tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        didChangeSectionInfo
            .subscribe(onNext: { [refreshControl] in
                refreshControl.endRefreshing()
            }, onError: { [refreshControl] in
                print("onError: \($0)")
                refreshControl.endRefreshing()
            })
            .disposed(by: disposeBag)

        viewDidLoadRelay.accept(())
    }

    @objc private func reloadTableView() {
        refreshRelay.accept(())
    }
}
// MARK: - ViewModel
struct ViewModel {
    func observeSectionInfo(
        viewDidLoad: PublishRelay<Void>,
        refresh: PublishRelay<Void>
    ) -> (
        sectionInfo: Driver<[SectionModel]>,
        didChangeSectionInfo: PublishSubject<Void>
    ) {
        let didChangeSectionInfo = PublishSubject<Void>()
        let sectionInfo = Observable.merge(viewDidLoad.asObservable(),
                                           refresh.asObservable())
            .map {
                [
                    SectionModel(title: "String Section",
                                 items: [.stringSection(.first),
                                         .stringSection(.second),
                                         .stringSection(.third)].shuffled()),
                    SectionModel(title: "Int Section",
                                 items: [.intSection(.first),
                                         .intSection(.second),
                                         .intSection(.third)].shuffled())
                ]
                .shuffled()
            }
            .do(afterNext: { _ in
                didChangeSectionInfo.onNext(())
            }, onError: {
                didChangeSectionInfo.onError($0)
            })
            .asDriver(onErrorRecover: { _ in
                fatalError()
            })

        return (sectionInfo: sectionInfo,
                didChangeSectionInfo: didChangeSectionInfo)
    }
}

