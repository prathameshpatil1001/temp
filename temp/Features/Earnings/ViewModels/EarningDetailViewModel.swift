//
//  EarningDetailViewModel.swift
//  DirectSalesTeamApp
//
//  Created by Apple on 17/04/26.
//


import Foundation
import Combine

class EarningDetailViewModel: ObservableObject {
    @Published var earning: EarningDetail
    
    init(earning: EarningDetail) {
        self.earning = earning
    }
}
