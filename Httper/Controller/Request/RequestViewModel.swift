//
//  RequestViewModel.swift
//  Httper
//
//  Created by Meng Li on 2018/9/12.
//  Copyright © 2018 MuShare Group. All rights reserved.
//

import RxSwift
import RxCocoa
import RxFlow
import RxKeyboard
import MGSelector
import Alamofire

struct DetailOption {
    var key: String
}

extension DetailOption: MGSelectorOption {
    
    var title: String {
        return key
    }
    
    var detail: String? {
        return NSLocalizedString(key, comment: "")
    }
    
}

class RequestViewModel: BaseViewModel {
    
    private let request: Request?
    private let headersViewModel: KeyValueViewModel
    private let parametersViewModel: KeyValueViewModel
    private let bodyViewModel: BodyViewModel
    
    init(request: Request?, headersViewModel: KeyValueViewModel, parametersViewModel: KeyValueViewModel, bodyViewModel: BodyViewModel) {
        self.request = request
        self.headersViewModel = headersViewModel
        self.parametersViewModel = parametersViewModel
        self.bodyViewModel = bodyViewModel
        
        if let method = request?.method {
            requestMethod.accept(method)
        }
        if let urlString = request?.url {
            let splits = urlString.split(separator: ":")
            requestProtocol.accept(protocols.firstIndex(of: String(splits[0])) ?? 0)
            var urlPart = splits[1]
            urlPart.removeFirst()
            urlPart.removeFirst()
            url.accept(String(urlPart))
        }
        if let requestData = request?.parameters as Data?, let parameters =  NSKeyedUnarchiver.unarchiveObject(with: requestData) as? Parameters {
            parametersViewModel.keyValues.accept(parameters.map {
                KeyValue(key: $0.key, value: $0.value as? String ?? "")
            })
        }
        if let headerData = request?.headers as Data?, let headers = NSKeyedUnarchiver.unarchiveObject(with: headerData) as? HTTPHeaders {
            headersViewModel.keyValues.accept(headers.map {
                KeyValue(key: $0.key, value: $0.value)
            })
        }
        if let bodyData = request?.body as Data?, let body = String(data: bodyData, encoding: .utf8) {
            bodyViewModel.body.accept(body)
        }
    }
    
    let protocols = ["http", "https"]
    let methods = ["GET", "POST", "HEAD", "PUT", "DELETE", "CONNECT", "OPTIONS", "TRACE", "PATCH"]
    
    let requestMethod = BehaviorRelay<String>(value: "GET")
    let url = BehaviorRelay<String?>(value: nil)
    let requestProtocol = BehaviorRelay<Int>(value: 0)
    
    var requestData: RequestData {
        return RequestData(
            method: requestMethod.value,
            url: protocols[requestProtocol.value] + "://" + (url.value ?? ""),
            headers: Array(headersViewModel.results.values),
            parameters: Array(parametersViewModel.results.values),
            body: bodyViewModel.body.value ?? ""
        )
    }
    
    var title: Observable<String> {
        return Observable.just(request).unwrap().map { _ in  "Request" }
    }
    
    var editingState: Observable<KeyValueEditingState> {
        return Observable.merge(headersViewModel.editingState, parametersViewModel.editingState).distinctUntilChanged {
            switch ($0, $1) {
            case (.begin(let height1), .begin(let height2)):
                return height1 == height2
            case (.end, .end):
                return true
            default:
                return false
            }
        }
    }
    
    var keyboardHeight: Observable<CGFloat> {
        return RxKeyboard.instance.visibleHeight.skip(1).asObservable().map { $0 + 35.0 }
    }
    
    func sendRequest() {
        guard let url = url.value, !url.isEmpty else {
            alert.onNext(.warning(R.string.localizable.url_empty()))
            return
        }
        steps.accept(RequestStep.result(requestData))
    }
    
    func saveToProject() {
        guard let url = url.value, !url.isEmpty else {
            alert.onNext(.warning(R.string.localizable.url_empty()))
            return
        }
        steps.accept(RequestStep.save(requestData))
    }
    
}
