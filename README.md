# wwdcdl
A downloader for WWDC session videos.

## Usage

Give the session web page URL as an argument.

`% wwdcdl https://developer.apple.com/videos/play/wwdc2022/102/`

## Compatibility

- ✅ WWDC22
- ✅ WWDC21
- ✅ WWDC20
- ✅ WWDC19
- ✅ WWDC18
- ✅ WWDC17
- ✅ WWDC16
- ✅ WWDC15

## Requires

- [`ffmpeg`](https://www.ffmpeg.org) and [`ffprobe`](https://www.ffmpeg.org)
- [`MP4Box`](https://github.com/gpac/gpac/wiki/MP4Box)
- [`jq`](https://stedolan.github.io/jq/)


## Notes

- Get the highest quality of HEVC or AVC video stream.
- Get US English and Japanese subtitles.
(To support other languages, you will need to modify the script.)
- Create a working directory on your current directory.
- For personal use.
