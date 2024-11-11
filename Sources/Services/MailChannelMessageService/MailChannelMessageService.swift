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
                                  completionHandler: @escaping (Result<[ChatMessageModel], Error>) -> Void) {
        
        let endpoint = "/web/dataset/search_read"
        var params: [String: Any] = [
            "context": ["lang": language, "tz": timezone, "uid": uid]
        ]
        
        switch request {
        case let .fetchChannelMessages(channelID, limit):
            params.merge([
                "model": "mail.message",
                "limit": limit,
                "domain": [
                    ["model", "=", "mail.channel"],
                    ["res_id", "=", channelID],
                    ["message_type", "in", ["email", "comment"]],
                    ["message_type", "!=", "notification"]
                ],
                "fields": ["id", "attachment_ids", "author_display", "body"]
            ]) { (_, new) in new }
            
        case let .fetchChannelNewMessages(channelID, limit, messagesID, comparisonOperator, userPartnerID, isChat):
            var domain: [[Any]] = [
                ["model", "=", "mail.message"],
                ["res_id", "=", channelID],
                ["message_type", "in", ["email", "comment"]],
                ["message_type", "!=", "notification"],
                ["id", comparisonOperator, messagesID]
            ]
            if comparisonOperator == ">" && isChat {
                domain.append(["author_id", "!=", userPartnerID])
            }
            params.merge([
                "model": "mail.message",
                "limit": limit,
                "domain": domain,
                "fields": ["id", "body", "attachment_ids", "author_display"]
            ]) { (_, new) in new }
            
        case let .fetchCheckOutMessages(channelID, messagesIDs):
            params.merge([
                "model": "mail.message",
                "domain": [
                    ["id", "in", messagesIDs],
                    ["res_id", "=", channelID],
                    ["message_type", "in", ["email", "comment"]],
                    ["message_type", "!=", "notification"]
                ],
                "fields": ["id", "attachment_ids"]
            ]) { (_, new) in new }
        }
        
        rpcClient.sendRPCRequest(endpoint: endpoint, method: .post, params: params) { result in
            switch result {
            case .success(let data):
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let records = json["records"] as? [[String: Any]] {
                        let recordsData = try JSONSerialization.data(withJSONObject: records)
                        let decoder = JSONDecoder()
                        let messages = try decoder.decode([ChatMessageModel].self, from: recordsData)
                        completionHandler(.success(messages))
                    } else {
                        completionHandler(.failure(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Expected `records` array in JSON"))))
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
