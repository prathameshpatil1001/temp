//
//  XMLParserService.swift
//  lms_project
//

import Foundation

// MARK: - XML Parser Service

class XMLParserService {
    static let shared = XMLParserService()
    
    private init() {}
    
    /// Parses XML data and returns extracted financial information.
    /// In production, this would use Foundation's XMLParser.
    /// For now, returns mock parsed data.
    func parseXMLData(_ data: Data) -> XMLParseResult {
        // Attempt real XML parsing
        if let xmlString = String(data: data, encoding: .utf8),
           xmlString.contains("<") {
            return parseRealXML(xmlString)
        }
        
        // Fallback to mock data
        return mockParseResult()
    }
    
    /// Simulates XML upload and parsing for demo purposes
    func simulateXMLUpload() -> XMLParseResult {
        return mockParseResult()
    }
    
    // MARK: - Private
    
    private func parseRealXML(_ xmlString: String) -> XMLParseResult {
        let parser = SimpleBankXMLParser(xmlString: xmlString)
        return parser.parse() ?? mockParseResult()
    }
    
    private func mockParseResult() -> XMLParseResult {
        return XMLParseResult(
            accountHolder: "Rajesh Kumar",
            bankName: "State Bank of India",
            accountNumber: "XXXX1234",
            monthlyIncome: 125000,
            averageBalance: 340000,
            transactions: [
                Transaction(id: "TXN-001", date: Calendar.current.date(byAdding: .day, value: -30, to: Date())!,
                            description: "Salary Credit - TCS", amount: 125000, type: .credit),
                Transaction(id: "TXN-002", date: Calendar.current.date(byAdding: .day, value: -25, to: Date())!,
                            description: "EMI - HDFC Home Loan", amount: 15000, type: .debit),
                Transaction(id: "TXN-003", date: Calendar.current.date(byAdding: .day, value: -20, to: Date())!,
                            description: "UPI Transfer", amount: 5000, type: .debit),
                Transaction(id: "TXN-004", date: Calendar.current.date(byAdding: .day, value: -15, to: Date())!,
                            description: "Rent Payment", amount: 25000, type: .debit),
                Transaction(id: "TXN-005", date: Calendar.current.date(byAdding: .day, value: -5, to: Date())!,
                            description: "Investment Returns", amount: 8500, type: .credit)
            ],
            totalCredits: 133500,
            totalDebits: 45000
        )
    }
}

// MARK: - Simple Bank XML Parser

private class SimpleBankXMLParser: NSObject, XMLParserDelegate {
    private let xmlString: String
    private var result: XMLParseResult?
    private var currentElement = ""
    private var currentText = ""
    
    private var accountHolder = ""
    private var bankName = ""
    private var accountNumber = ""
    private var monthlyIncome: Double = 0
    private var averageBalance: Double = 0
    
    init(xmlString: String) {
        self.xmlString = xmlString
    }
    
    func parse() -> XMLParseResult? {
        guard let data = xmlString.data(using: .utf8) else { return nil }
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return result
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentText = ""
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        switch elementName {
        case "AccountHolder": accountHolder = currentText
        case "BankName": bankName = currentText
        case "AccountNumber": accountNumber = currentText
        case "MonthlyIncome": monthlyIncome = Double(currentText) ?? 0
        case "AverageBalance": averageBalance = Double(currentText) ?? 0
        default: break
        }
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        result = XMLParseResult(
            accountHolder: accountHolder.isEmpty ? "Unknown" : accountHolder,
            bankName: bankName.isEmpty ? "Unknown Bank" : bankName,
            accountNumber: accountNumber.isEmpty ? "XXXX0000" : accountNumber,
            monthlyIncome: monthlyIncome,
            averageBalance: averageBalance,
            transactions: [],
            totalCredits: monthlyIncome,
            totalDebits: 0
        )
    }
}
