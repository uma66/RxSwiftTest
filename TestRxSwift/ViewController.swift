//
//  ViewController.swift
//  TestRxSwift
//
//  Created by uma6 on 2017/02/03.
//  Copyright © 2017年 uma6. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import RxBlocking

infix operator <-> : DefaultPrecedence

func nonMarkedText(_ textInput: UITextInput) -> String? {
    let start = textInput.beginningOfDocument
    let end = textInput.endOfDocument
    
    guard let rangeAll = textInput.textRange(from: start, to: end),
        let text = textInput.text(in: rangeAll) else {
            return nil
    }
    
    guard let markedTextRange = textInput.markedTextRange else {
        return text
    }
    
    guard let startRange = textInput.textRange(from: start, to: markedTextRange.start),
        let endRange = textInput.textRange(from: markedTextRange.end, to: end) else {
            return text
    }
    
    return (textInput.text(in: startRange) ?? "") + (textInput.text(in: endRange) ?? "")
}


func <-> <Base: UITextInput>(textInput: TextInput<Base>, variable: Variable<String>) -> Disposable {
    let bindToUIDisposable = variable.asObservable()
        .bindTo(textInput.text)
    let bindToVariable = textInput.text
        .subscribe(onNext: { [weak base = textInput.base] n in
            guard let base = base else {
                return
            }
            
            let nonMarkedTextValue = nonMarkedText(base)
            
            /**
             In some cases `textInput.textRangeFromPosition(start, toPosition: end)` will return nil even though the underlying
             value is not nil. This appears to be an Apple bug. If it's not, and we are doing something wrong, please let us know.
             The can be reproed easily if replace bottom code with
             
             if nonMarkedTextValue != variable.value {
             variable.value = nonMarkedTextValue ?? ""
             }
             
             and you hit "Done" button on keyboard.
             */
            if let nonMarkedTextValue = nonMarkedTextValue, nonMarkedTextValue != variable.value {
                variable.value = nonMarkedTextValue
            }
            }, onCompleted:  {
                bindToUIDisposable.dispose()
        })
    
    return Disposables.create(bindToUIDisposable, bindToVariable)
}

func <-> <T>(property: ControlProperty<T>, variable: Variable<T>) -> Disposable{
    let bindToUIDisposable = variable.asObservable().debug("Variable values in bind")
        .bindTo(property)
    
    let bindToVariable = property
        .debug("Property values in bind")
        .subscribe(onNext: { n in
            variable.value = n
        }, onCompleted:  {
            bindToUIDisposable.dispose()
        })
    
    return Disposables.create(bindToUIDisposable, bindToVariable)
}

func <-> <T>(property: ControlProperty<T?>, variable: Variable<T>) -> Disposable{
    let bindToUIDisposable = variable.asObservable().debug("Variable values in bind")
        .bindTo(property)
    
    let bindToVariable = property
        .debug("Property values in bind")
        .subscribe(onNext: { n in
            if let _ = n {
            variable.value = n!
            }
        }, onCompleted:  {
            bindToUIDisposable.dispose()
        })
    
    return Disposables.create(bindToUIDisposable, bindToVariable)
}

func <-> <T: Comparable>(left: Variable<T>, right: Variable<T>) -> Disposable {
    let leftToRight = left.asObservable()
        .distinctUntilChanged()
        .bindTo(right)
    
    let rightToLeft = right.asObservable()
        .distinctUntilChanged()
        .bindTo(left)
    
    return Disposables.create(leftToRight, rightToLeft)
}

/*
func <-> <T>(property: ControlProperty<T>, variable: Variable<T>) -> Disposable {
    if T.self == String.self {
        #if DEBUG
            fatalError("It is ok to delete this message, but this is here to warn that you are maybe trying to bind to some `rx.text` property directly to variable.\n" +
                "That will usually work ok, but for some languages that use IME, that simplistic method could cause unexpected issues because it will return intermediate results while text is being inputed.\n" +
                "REMEDY: Just use `textField <-> variable` instead of `textField.rx.text <-> variable`.\n" +
                "Find out more here: https://github.com/ReactiveX/RxSwift/issues/649\n"
            )
        #endif
    }
    
    let bindToUIDisposable = variable.asObservable()
        .bindTo(property)
    let bindToVariable = property
        .subscribe(onNext: { n in
            variable.value = n
        }, onCompleted:  {
            bindToUIDisposable.dispose()
        })
    
    return Disposables.create(bindToUIDisposable, bindToVariable)
}
*/

class ViewController: UIViewController {
    
    var str2 = Variable<String?>("あいうえお")
    
    var str = Variable<String>("あいうえお") {
        didSet {
            print("ワオワオ")
        }
    }
    var inputText: String? {
        didSet {
            print("セットされた")
        }
    }
    let bag = DisposeBag()
    @IBOutlet weak var testField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        testField.text = "初期"
        
        /*
        // 双方向バインディング
        str.asObservable().bindTo(testField.rx.text).addDisposableTo(bag)
        (testField.rx.text.subscribe{ [unowned self] in
            print("subscribe")
            self.inputText = $0.debugDescription
        }).addDisposableTo(bag)
        */
        
        // 双方向バインディング
        (testField.rx.text <-> str).addDisposableTo(bag)
        
        // didSetを使っても良いし、RxSwiftで宣言しておいても良い。ロジックを。Dto内で。
        str.asObservable().distinctUntilChanged().subscribe { str in
            
        }.addDisposableTo(bag)
        
        
        str2.asObservable()
            .map { $0 }
            .bindTo(testField.rx.text)
            .addDisposableTo(bag)
        
        
//        testField.rx.text.subscribe(onNext:{})
        
        // ↓うまくいかない
//        testField.rx.text <-> str
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.test()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            print(self.str.value)
        }
        
    }
    
    func test() {
        str.value = "変更した！"
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

