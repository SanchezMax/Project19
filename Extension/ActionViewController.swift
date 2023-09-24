//
//  ActionViewController.swift
//  Extension
//
//  Created by Максим Зыкин on 22.09.2023.
//

import UIKit
import MobileCoreServices
import UniformTypeIdentifiers

class ActionViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet var script: UITextView!
    
    var pageTitle = ""
    var pageURL = ""
    
    var scripts = [(name: String, script: String)]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(chooseScript))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(howToSave))
        
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(adjustForKeyboard), name: UIResponder.keyboardWillHideNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(adjustForKeyboard), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        
        if let inputItem = extensionContext?.inputItems.first as? NSExtensionItem {
            if let itemProvider = inputItem.attachments?.first {
                itemProvider.loadItem(forTypeIdentifier: UTType.propertyList.identifier as String) { [weak self] (dict, error) in
                    guard let itemDictionary = dict as? NSDictionary else { return }
                    guard let javaScriptDictionary = itemDictionary[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary else { return }
                    
                    self?.pageTitle = javaScriptDictionary["title"] as? String ?? ""
                    self?.pageURL = javaScriptDictionary["URL"] as? String ?? ""
                    
                    DispatchQueue.main.async {
                        self?.title = self?.pageTitle
                        self?.loadScriptForSite()
                        self?.loadScriptsForTable()
                    }
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return scripts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Script", for: indexPath)
        cell.textLabel?.text = scripts[indexPath.row].name
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        script.text.append(scripts[indexPath.row].script)
    }

    @IBAction func done() {
        saveScriptForSite()
        
        let item = NSExtensionItem()
        let argument: NSDictionary = ["customJavaScript": script.text]
        let webDictionary: NSDictionary = [NSExtensionJavaScriptFinalizeArgumentKey: argument]
        let customJavaScript = NSItemProvider(item: webDictionary, typeIdentifier: UTType.propertyList.identifier as String)
        item.attachments = [customJavaScript]
        
        extensionContext?.completeRequest(returningItems: [item])
    }
    
    @objc func howToSave() {
        let ac = UIAlertController(title: "How do you want to proceed?", message: nil, preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "Save script for this site and launch it", style: .default) { [weak self] _ in
            self?.done()
        })
        ac.addAction(UIAlertAction(title: "Save script for reuse in table", style: .default) { [weak self] _ in
            self?.saveScriptForTable()
        })
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(ac, animated: true)
    }
    
    func loadScriptsForTable() {
        let defaults = UserDefaults.standard
        guard let savedScripts = defaults.dictionary(forKey: "ScriptsTable") as? [String: String] else { return }
        scripts = savedScripts.map { savedScript in
            (name: savedScript.key, script: savedScript.value)
        }
        tableView.reloadData()
    }
    
    func saveScriptForTable() {
        let ac = UIAlertController(title: "Please enter the name for the script", message: nil, preferredStyle: .alert)
        ac.addTextField()
        ac.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            guard let name = ac.textFields?.first?.text else { return }
            guard let script = self?.script.text else { return }
            self?.scripts.append(
                (
                    name: name,
                    script: script
                )
            )
            let defaults = UserDefaults.standard
            var dictionaryToSave: [String: String] {
                var result = [String: String]()
                self?.scripts.forEach { script in
                    result[script.name] = script.script
                }
                return result
            }
            defaults.setValue(dictionaryToSave,forKey: "ScriptsTable")
            
            self?.tableView.reloadData()
            
        })
        present(ac, animated: true)
    }
    
    @objc func chooseScript() {
        let ac = UIAlertController(title: "Choose script", message: nil, preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "Alert title", style: .default) { [weak self] _ in
            self?.script.text.append("alert(document.title);")
        })
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(ac, animated: true)
    }
    
    func loadScriptForSite() {
        guard let url = URL(string: pageURL)?.host(percentEncoded: true) else { return }
        let defaults = UserDefaults.standard
        if let savedScript = defaults.string(forKey: url) {
            script.text = savedScript
        }
    }
    
    func saveScriptForSite() {
        guard let url = URL(string: pageURL)?.host(percentEncoded: true) else { return }
        let defaults = UserDefaults.standard
        defaults.setValue(script.text, forKey: url)
    }
    
    @objc func adjustForKeyboard(notification: Notification) {
        guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }

        let keyboardScreenEndFrame = keyboardValue.cgRectValue
        let keyboardViewEndFrame = view.convert(keyboardScreenEndFrame, from: view.window)

        if notification.name == UIResponder.keyboardWillHideNotification {
            script.contentInset = .zero
        } else {
            script.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardViewEndFrame.height - view.safeAreaInsets.bottom, right: 0)
        }

        script.scrollIndicatorInsets = script.contentInset

        let selectedRange = script.selectedRange
        script.scrollRangeToVisible(selectedRange)
    }
}
