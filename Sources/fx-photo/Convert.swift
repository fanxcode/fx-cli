//
//  File.swift
//  fx-cli
//
//  Created by fan xian on 2025/8/9.
//

import ArgumentParser

struct Convert: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "convert",
        abstract: "将图片转换为 HEIC 格式"
    )

    func run() throws {
        print("转换执行了")
    }
}
