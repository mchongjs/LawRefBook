//
//  LawContentView.swift
//  law.handbook
//
//  Created by Hugh Liu on 26/2/2022.
//

import Foundation
import SwiftUI

struct TextContent : Identifiable {
    var id: UUID = UUID()
    var text: String
    var children: [String]
}

struct Info: Identifiable {
    var id: UUID = UUID()
    var header: Substring
    var content: Substring = ""
}

class LawModel: ObservableObject {
    @Published var Name: String = ""
    @Published var Desc: [Info] = []
    @Published var Body: [TextContent] = []
    
    init(law: Law) {
        var dir = "法律法条"
        if law.folder != nil {
            dir += "/" + law.folder!
        }
        var filename = law.file
        if filename == nil {
            filename = law.name
        }
        if let filepath = Bundle.main.path(forResource: filename, ofType: "md", inDirectory: dir) {
            do {
                let contents = try String(contentsOfFile: filepath)
                DispatchQueue.main.async {
                    let arr = contents.components(separatedBy: "\n").map{text in
                        return text.trimmingCharacters(in: [" ", "\n"])
                    }.filter{ line in
                        return !line.isEmpty
                    }
                    
                    var isDesc = true
                    
                    for (index, text) in arr.enumerated() {
                        
                        if text.isEmpty {
                            continue
                        }
                        
                        let out = text.split(separator: " ", maxSplits: 1)
                        if out.isEmpty {
                            continue
                        }
                        
                        if index == 0{
                            // 标题
                            self.Name = String(out[1])
                            continue
                        }
                        
                        if text == "<!-- INFO END -->" {
                            isDesc = false
                            continue
                        }
                        
                        if isDesc {
                            var info = Info(header: out[0])
                            if out.count > 1 {
                                info.content = out[1]
                            }
                            self.Desc.append(info)
                            continue
                        }
                        
                        if out[0].hasPrefix("#") {
                            self.Body.append(TextContent(text: String(out[1]), children: []))
                        } else {
                            let lastChildren = self.Body[self.Body.count - 1].children
                            let result = text.range(of: "第.+条", options: .regularExpression)
                            if lastChildren.isEmpty || result != nil {
                                self.Body[self.Body.count - 1].children.append(contentsOf: [text])
                            }else{
                                let len = self.Body[self.Body.count - 1].children.count
                                self.Body[self.Body.count - 1].children[len - 1] += "\n    "
                                self.Body[self.Body.count - 1].children[len - 1] += text
                            }
                        }
                    }
                }
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        } else {
            print("File not found")
        }
    }
}

func OpenMail(subject: String, body: String) {
    let info = String(format: "Version:%@", body, UIApplication.appVersion ?? "")
    let mailTo = String(format: "mailto:%@?subject=%@&body=%@\n\n%@", DeveloperMail, subject,body,info)
        .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    let mailtoUrl = URL(string: mailTo!)!
    if UIApplication.shared.canOpenURL(mailtoUrl) {
        UIApplication.shared.open(mailtoUrl, options: [:])
    }
}

func Report(law: LawModel, line: String){
    let subject = String(format: "反馈问题:%@", law.Name)
    let body = line
    OpenMail(subject: subject, body: body)
}

struct CenterFullTextInList: View {
    @Binding var content: String
    
    var body: some View {
        Text(content)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .listRowSeparator(.hidden)
    }
}

struct LawInfoPage: View {
    @ObservedObject var model: LawModel
    
    var body: some View {
        List {
            ForEach(model.Desc, id: \.id) { info in
                if !info.content.isEmpty {
                    Section(header: Text(info.header)){
                        Text(info.content)
                    }
                }else{
                    Text(info.header)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .listRowSeparator(.hidden)
                }
            }
        }.listStyle(.plain)
    }
}

struct LawContentList: View {
    
    @ObservedObject var model: LawModel
    @Binding var searchText: String
    @State var showInfoPage = false
    
    @Environment(\.managedObjectContext) var moc
    
    func HightedText(str: String, searched: String) -> Text {
        guard !str.isEmpty && !searched.isEmpty else { return Text(str) }
        
        var result: Text!
        let parts = str.components(separatedBy: searched)
        for i in parts.indices {
            result = (result == nil ? Text(parts[i]) : result + Text(parts[i]))
            if i != parts.count - 1 {
                result = result + Text(searched).bold().font(.title)
            }
        }
        return result ?? Text(str)
    }
    
    var body: some View {
        List {
            CenterFullTextInList(content: $model.Name).font(.title)
            ForEach(Array(model.Body.enumerated()), id: \.offset){ i, body in
                let contentArr = body.children.filter { searchText.isEmpty || $0.contains(searchText)}
                if !contentArr.isEmpty {
                    Section(header: Text(body.text)){
                        ForEach(Array(contentArr.enumerated()), id: \.offset){ j, text in
                            HightedText(str: text, searched: searchText)
                                .id(body.id)
                                .swipeActions {
                                    Button {
                                        Report(law: model, line: text)
                                    } label: {
                                        Label("反馈", systemImage: "exclamationmark.circle")
                                    }
                                    .tint(.red)
                                    
                                    Button {
                                        let fav = Favouite(context: moc)
                                        fav.id = UUID()
                                        fav.content = text
                                        fav.law = model.Name
                                        try? moc.save()
                                    } label: {
                                        Label("收藏", systemImage: "heart")
                                    }
                                    .tint(.orange)
                                }
                        }
                    }
                    
                }
            }
        }.listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showInfoPage.toggle()
                    }, label: {
                        Image(systemName: "info.circle")
                    }).foregroundColor(.red)
                        .sheet(isPresented: $showInfoPage) {
                            LawInfoPage(model: model)
                        }
                }
            }
    }
}

struct LawContentView: View {
    
    @ObservedObject var model: LawModel
    @State var searchText = ""
    
    var body: some View{
        LawContentList(model: model, searchText: $searchText)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText)
    }
}

struct LawContentView_Previews:PreviewProvider {
    static var previews: some View {
        Group {
            LawContentView(model: LawModel(law: Law(name: "消费者权益保护法")))
        }.previewDevice(PreviewDevice(rawValue: "iPhone 13 Pro"))
    }
}

