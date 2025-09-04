// The Swift Programming Language
// https://docs.swift.org/swift-book
import ArgumentParser

@main
struct fx_photo: ParsableCommand {
    // ArgumentParser提供的方法，直接写好配置就可以配置命令行
    static let configuration = CommandConfiguration(
        commandName: "fx-photo",
        abstract: "图片处理工具",
        discussion: """
                支持多种图片处理功能，比如转换格式、追加图片等。
                使用示例：
                  fx-photo convert <输入路径>
                  fx-photo append <图片1> <图片2>
                """,                                     // 可选，详细描述
        version: "1.0.0",                         // 可选 --version
        subcommands: [
            Convert.self,                         // fx-photo convert ...
            Time.self,
//            Append.self                           // fx-photo append ...
        ],
        defaultSubcommand: nil
    )
}
