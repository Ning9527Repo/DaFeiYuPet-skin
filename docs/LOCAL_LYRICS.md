# 本地逐句歌词（试验性）

不从汽水音乐读取歌词，也不联网查询。需用户自己提供合法持有的逐句 LRC 与歌曲信息。将属性列表保存为 bootstrap 的 `/Library/Application Support/AxsDaFeiYuPet/lyrics.plist`（roothide 用 jbroot 对应路径；rootless 用 `/var/jb` 前缀）。更换文件后 respring；不会覆盖应用数据。当前只支持一个已导入歌曲。

XML 属性列表的根为 dictionary：`title`（字符串，须与系统 Now Playing 标题完全相同）、`artist`（字符串，须完全相同）、`duration`（歌曲时长，秒，数字，容差 2 秒）、`lrc`（含 `[mm:ss.xx]歌词` 的字符串）。例如：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>title</key><string>歌曲名称</string>
<key>artist</key><string>演唱者</string>
<key>duration</key><real>180.0</real>
<key>lrc</key><string>[00:01.00]第一句
[00:05.00]第二句</string>
</dict></plist>
```

播放状态、标题、歌手、时长、经过时间、更新时间及速率缺一不可；未知／过期元数据、暂停、切歌、首句之前和锁屏时不显示。查询每 3 秒一次，因此存在更新延迟。其他播放器若播放完全相同的标题、歌手与时长，现阶段也可能匹配；尚未验证播放器身份接口，不应认为只针对汽水音乐。聊天／菜单和事件提示优先显示。只在启动时后台读取本地文件；文件超过 600 KB 或格式不合法会被忽略，歌词内容不写进日志。

目前无用户提供的 LRC 文件，也无导入界面：在用户明确授权将具体文件写入该 bootstrap 路径前，本工程不会写入任何歌词。不能将“代码可编译”当作实际同步显示已验证。
