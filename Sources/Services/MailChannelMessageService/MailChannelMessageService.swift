//
//  MailChannelMessageService.swift
//  OdooRPC
//
//  Created by Peter on 31.10.2024.
//

import Foundation

public class MailChannelMessageService {
    private let rpcClient: RPCClient
    
    // Initializer for MailChannelMessageService, takes an RPCClient instance
    init(rpcClient: RPCClient) {
        self.rpcClient = rpcClient
    }
    
    public func requestAttachment(request: MailChannelMessageAction,
                           language: String,
                           timezone: String,
                           uid: Int,
                           completionHandler: @escaping (Result<[ChatMessageModel], Error>) -> Void ) {
        
        let endpoint = "/web/dataset/search_read"
        var params: [String: Any] = ["context": ["lang": language as Any, "tz": timezone as Any, "uid": uid as Any]]
        
        switch request {
        case let .fetchChannelMessages(channelID, limit):
            params.merge([
                "model": "mail.channel",
                "limit": limit,
                "domain": [
                    ["is_member", "!=", false],
                    ["res_id", "=", channelID]
                ],
                "fields": ["id", "body", "attachment_ids", "author_display"]
            ], uniquingKeysWith: { (_, new) in new })
            
        case let .fetchChannelNewMessages(channelID, limit, messagesID, comparisonOperator, userPartnerID, isChat):
            var domain: [[String: Any]] = [
                ["model": "=", "value": "mail.channel"],
                ["res_id": "=", "value": channelID],
                ["id": comparisonOperator, "value": messagesID]
            ]
            if comparisonOperator == ">" && isChat {
                domain.append(["author_id": "!=", "value": userPartnerID])
            }
            params.merge([
                "model": "mail.message",
                "limit": limit,
                "domain": domain,
                "fields": ["id", "body", "attachment_ids", "author_display"]
            ], uniquingKeysWith: { (_, new) in new })
            
        case let .fetchCheckOutMessages(channelID, messagesIDs):
            params.merge([
                "model": "mail.message",
                "domain": [
                    ["id": "in", "value": messagesIDs],
                    ["res_id": "=", "value": channelID]
                ],
                "fields": ["id", "body", "attachment_ids"]
            ], uniquingKeysWith: { (_, new) in new })
        }
        
        rpcClient.sendRPCRequest(endpoint: endpoint, method: .post, params: params) { result in
            switch result {
            case .success(let data):
                do {
                    // Attempt to decode a wrapper if present
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let records = json["records"] as? [[String: Any]] {
                        // Convert records to JSON data
                        let recordsData = try JSONSerialization.data(withJSONObject: records)
                        
                        // Decode the ChatMessageModel array from records data
                        let decoder = JSONDecoder()
                        let messages = try decoder.decode([ChatMessageModel].self, from: recordsData)
                        completionHandler(.success(messages))
                    } else {
                        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Expected `records` array in JSON"))
                    }
                } catch {
                    completionHandler(.failure(error))
                }
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }
}
