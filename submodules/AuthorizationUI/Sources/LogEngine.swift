//
//  LogEngine.swift
//  Telegram
//
//  Created by xjj on 2025/10/15.
//

import Foundation

@available(iOS 15.0, *)
extension Task where Success == Never, Failure == Never {
    static func sleep(seconds:UInt64) async {
        do {
            try await Task.sleep(nanoseconds: seconds * NSEC_PER_SEC);
        }
        catch (let exception){
            NSLog("sleep exception: \(exception)");
        }
    }
}

typealias AppUploadCompletion = (_ isOK:Bool) -> Void;

class LogEngine {
    
    private static let _engine: LogEngine = LogEngine();
    static let shared: LogEngine = {
        return _engine;
    }();
    
    func uploadLog(completion: @escaping AppUploadCompletion){
        
        
        let sourcePath = NSHomeDirectory() + "/Documents/groups/telegram-data/logs"
        let sourceURL = URL(fileURLWithPath: sourcePath);
        let t = Int64(Date().timeIntervalSince1970 * 1000);
        let destinationPath = NSHomeDirectory() + "/Documents/groups/telegram-data/logs_x_\(t).zip"
        let destinationURL = URL(fileURLWithPath: destinationPath);
        do {
            try zipDirectory(sourceURL: sourceURL, destinationURL: destinationURL);
            NSLog("upload successfully:\(destinationPath)");
            
            if #available(iOS 15.0, *) {
                Task {
                    let url = await uploadImage(destinationPath)
                    NSLog("upload successfully:\(url)");
                    await MainActor.run {
                        completion(true);
                    }
                }
            } else {
                NSLog("OK")
                completion(false);
            }
        }
        catch (let e){
            NSLog("upload exception:\(e)");
            completion(false);
        }
    }
    
    @available(iOS 15.0, *)
    private func uploadFile(_ image:String, url:String) async -> Bool {
        do {
            var request = URLRequest(url: URL(string: url)!);
            request.httpMethod = "PUT";
            let (_, response) = try await URLSession.shared.upload(for: request, fromFile: URL(fileURLWithPath: image));
            guard let response = response as? HTTPURLResponse else { return false }
            return response.statusCode == 200;
        }
        catch(let exception) {
            NSLog("put file exception:\(exception)")
        }
        return false;
    }
    
    @available(iOS 15.0, *)
    func uploadImage(_ image:String) async -> String {
        if image.hasPrefix("http") {
            return image;
        }
        var request = URLRequest(url: URL(string: "http://47.84.40.124/v1/api/presign")!);
        request.httpMethod = "POST";
        var body = [AnyHashable:AnyHashable]();
        let imageURL = URL(fileURLWithPath: image);
        
        do {
            body["name"] = imageURL.lastPathComponent;
            body["preset_id"] = "applogs";
            body["size"] = try FileManager.default.attributesOfItem(atPath: image)[FileAttributeKey.size]! as? AnyHashable;
            let bodyJSON = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted);
            request.httpBody = bodyJSON;
            let (body, _) = try await URLSession.shared.data(for: request);
            
            guard let xbody = try JSONSerialization.jsonObject(with: body, options: .mutableContainers) as? [String:AnyHashable] else {
                return "";
            }
            
            let code = xbody["code"] as? Int ?? 0;
            if code != 200 {
                return "";
            }
            
            let put_url = xbody["url"] as! String;
            var isOK = await uploadFile(image, url: put_url);
            if !isOK {
                await Task.sleep(seconds: 3)
                isOK = await uploadFile(image, url: put_url);
            }
            if !isOK {
                return "";
            }
            let access_url = xbody["access_url"] as! String;
            return access_url;
            
        }
        catch (let exception) {
            NSLog("presign exception: \(exception)")
            return "";
        }
    }
    
    func zipDirectory(sourceURL: URL, destinationURL: URL) throws {
        let fileManager = FileManager()
        
        // 如果目标文件存在，先删除
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        try fileManager.zipItem(at: sourceURL, to: destinationURL)
    }
    
}
