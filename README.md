# wwdcdl
A downloader for WWDC session videos.

## Usage

Give the session web page URL as an argument.

`% wwdcdl https://developer.apple.com/videos/play/wwdc2022/102/`

## Compatibility

- ✅ WWDC23
- ✅ WWDC22
- ✅ WWDC21
- ✅ WWDC20
- ✅ WWDC19
- ✅ WWDC18
- ✅ WWDC17
- ✅ WWDC16
- ✅ WWDC15

Currently Dolby-Atmos audio is not supported because I have not found a way to properly mux them to QuickTime compatible mp4 format.

## Requires

- curl
- [`ffmpeg`](https://www.ffmpeg.org) and [`ffprobe`](https://www.ffmpeg.org)
- [`MP4Box`](https://github.com/gpac/gpac/wiki/MP4Box)
- [`jq`](https://stedolan.github.io/jq/)
- [`trash`](https://hasseg.org/trash/)


## Notes

- Get the highest quality of HEVC or AVC video stream.
- Get US English and Japanese subtitles.
(To support other languages, you will need to modify the script.)
- Create a working directory on your current directory.
- Currently Dolby-Atmos audio is not supported because I have not found a way to properly mux them to QuickTime compatible mp4 format.
- For personal use.
