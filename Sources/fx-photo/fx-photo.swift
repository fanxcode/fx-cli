// The Swift Programming Language
// https://docs.swift.org/swift-book
import ArgumentParser

@main
struct fx_photo: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "fx-photo",
        abstract: "图片处理工具",
        discussion: """
                支持多种图片处理功能，比如转换格式、追加图片等。
                使用示例：
                  fx-photo convert <输入路径>
                  fx-photo time "yyyy-mm-dd hh:mm:ss" <输入路径>
                """,
        version: "1.0.0",
        subcommands: [
            // fx-photo convert ...
            Convert.self,
            // fx-photo time "yyyy-mm-dd hh:mm:ss"
            Time.self,
        ],
        defaultSubcommand: nil
    )
}
