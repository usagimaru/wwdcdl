#!/bin/sh

# Intermediate output files
main_hls_path="main.m3u8"
video_outpath="video.mp4"
remux_hevc_path="remux_hevc.mp4"
final_video_path=$video_outpath
audio_outpath="audio.m4a"
stt_path_en="en.vtt"
stt_path_ja="ja.vtt"

video_hvc_uri=""
video_avc_uri=""
audio_uri=""
stt_uri_en=""
stt_uri_ja=""

# ---------------------------------------

# URL availability check
function exists_url () {
	if [ $# != 1 ]; then
		echo "not exists"
		exit 1
	fi
	
	local arg=$1
	
	if ! [[ $arg =~ https?:\/\/.* ]]; then
		echo "not exists"
		exit 1
	fi
	
	local regex="HTTP/.* 200"
	local httpstatus=`curl --head --silent $arg | grep -e "HTTP/.* 200"`
	
	#echo $arg
	#echo $httpstatus
	
	if [[ $httpstatus =~ $regex ]]; then
		echo "exists"
	else
		echo "not exists"
	fi
}

# Get video condec name
function videoCodecName () {
	local vcodec=`ffprobe -hide_banner -i $1 -show_streams -v error | grep codec_name | sed -E 's/codec_name=(.*)/\1/'`
	
	echo "$vcodec"
}

# Extract title from HTML
function getHTMLTitle () {
	# Extract 'title' tag in the HTML text
	local web_title=`curl -fsSL $1 | grep -i "</title>" | sed -E "s/<title>(.*)<\/title>/\1/"`
	# Extract title string
	local title=${web_title%% - *}
	# Replace '/', ':' to '-' (Safety for macOS File System)
	title=`echo $title | sed -e "s/[\/:]/-/g"`
	
	echo $title
}

# Get URIs from HLS file
function getURIs () {
	# e.g. Subtitle URIs
	# "subtitles/eng/prog_index.m3u8"
	# "subtitles/jpn/prog_index.m3u8"
	
	# e.g. Video & audio URIs
	# "cmaf/hvc/2160p_16800/hvc_2160p_16800.m3u8"
	# "cmaf/avc/1080p_6000/avc_1080p_6000.m3u8"
	# "cmaf/aac/lc_192/aac_lc_192.m3u8"


	# HEVC URI
	video_hvc_uri=`cat $main_hls_path | grep ".m3u8" | grep "hvc" | grep -iv "i-frame" | sort -fVr | grep -m 1 ".*"`
	
	# AVC URI
	video_avc_uri=`cat $main_hls_path | grep ".m3u8" | grep "avc" | grep -iv "i-frame" | sort -fVr | grep -m 1 ".*"`
	
	# Audio URI
	audio_uri=`cat $main_hls_path | grep ".m3u8" | grep "EXT-X-MEDIA:TYPE=AUDIO" | sed -E "s/.*URI=\"(.*\.m3u8)\".*/\1/"`
	
	# Subtitle URI en
	stt_uri_en=`cat $main_hls_path | grep ".m3u8" | grep "EXT-X-MEDIA:TYPE=SUBTITLES" | grep -i "name=\"English\"" | sed -E "s/.*URI=\"(.*\.m3u8)\".*/\1/"`
	
	# Subtitle URI ja
	stt_uri_ja=`cat $main_hls_path | grep ".m3u8" | grep "EXT-X-MEDIA:TYPE=SUBTITLES" | grep -i "name=\"日本語\"" | sed -E "s/.*URI=\"(.*\.m3u8)\".*/\1/"`
		
	if [ -n "$video_hvc_uri" ]; then
		echo HVC Video URI: \"$video_hvc_uri\"
	else
		echo HVC Video URI: none
	fi
	
	if [ -n "$video_avc_uri" ]; then
		echo AVC Video URI: \"$video_avc_uri\"
	else
		echo AVC Video URI: none
	fi
	
	if [ -n "$audio_uri" ]; then
		echo Audio URI: \"$audio_uri\"
	else
		echo Audio URI: none
	fi
	
	# Subtitle en
	if [ -n "$stt_uri_en" ]; then
		echo Subtitle URI English: \"$stt_uri_en\"
	else
		echo Subtitle URI English: none
	fi
	
	# Subtitle ja
	if [ -n "$stt_uri_ja" ]; then
		echo Subtitle URI 日本語: \"$stt_uri_ja\"
	else
		echo Subtitle URI 日本語: none
	fi
	
	# Other languages...
	
	echo "========================================"
}


# Download processes
function dlprocess () {
	local video_url=$hls_base_url/$video_avc_uri
	if [ -n $video_hvc_uri ]; then
		video_url=$hls_base_url/$video_hvc_uri
	fi
	
	local audio_url=$hls_base_url/$audio_uri
	
	local stt_url_en=""
	if [ -n $stt_uri_en ]; then
		stt_url_en=$hls_base_url/$stt_uri_en
	fi
	
	local stt_url_ja=""
	if [ -n $stt_uri_ja ]; then
		stt_url_ja=$hls_base_url/$stt_uri_ja
	fi
	
	# Subtitle en
	if [[ `exists_url $stt_url_en` == "exists" ]] && [ ! -e "$stt_path_en" ]; then
		ffmpeg -i $stt_url_en $stt_path_en
	else 
		echo $stt_url_en
		echo `exists_url $stt_url_en`
		echo "stt en not exists"
	fi
	
	# Subtitle ja
	if [[ `exists_url $stt_url_ja` == "exists" ]] && [ ! -e "$stt_path_ja" ]; then
		ffmpeg -i $stt_url_ja $stt_path_ja
	else 
		echo "stt ja not exists"
	fi
	
	# Audio (en)
	if [[ `exists_url $audio_url` == "exists" ]] && [ ! -e "$audio_outpath" ]; then
		ffmpeg -i $audio_url -c copy $audio_outpath
	else 
		echo "audio not exists"
	fi
		
	# Video
	if [[ `exists_url $video_url` == "exists" ]] && [ ! -e "$video_outpath" ]; then
		local cmd="ffmpeg -i $video_url -c copy $video_outpath"
		#echo $cmd
		eval $cmd
	else 
		echo "video not exists"
	fi
	
	if [ -e "$video_outpath" ]; then
		final_video_path=$video_outpath
		
		# Remux HEVC (To create QuickTime friendly video file)
		if [[ `videoCodecName $video_outpath` == "hevc" ]]; then
			local hvc_path=${video_outpath%.*}"_track1.hvc"
			mp4box -raw 1 $video_outpath
			mp4box -add $hvc_path $remux_hevc_path
			
			final_video_path=$remux_hevc_path
		fi
	fi
}


# Execute joining
function joinFiles () {
	local isVideo=0
	local isAudio=0
	local isSTT_en=0
	local isSTT_ja=0
	local cmdchain="ffmpeg "
	
	if [ -e "$final_video_path" ]; then
		cmdchain+="-i $final_video_path "
		isVideo=1
	fi
	
	if [ -e "$audio_outpath" ]; then
		cmdchain+="-i $audio_outpath "
		isAudio=1
	fi
	
	if [ -e "$stt_path_en" ]; then
		cmdchain+="-i $stt_path_en "
		isSTT_en=1
	fi
	
	if [ -e "$stt_path_ja" ]; then
		cmdchain+="-i $stt_path_ja "
		isSTT_ja=1
	fi
	
	
	local mapCount=0
	if [ $isVideo == 1 ] && [ $isAudio == 1 ]; then
		cmdchain+="-map 0 -map 1 "
		mapCount=1
	fi
	
	if [ $isSTT_en == 1 ]; then
		cmdchain+="-map 2 "
		mapCount=2
	fi
	
	if [ $isSTT_ja == 1 ]; then
		mapCount=`expr $mapCount + 1`
		cmdchain+="-map $mapCount "
	fi
	
	if [ $isVideo == 1 ] && [ $isAudio == 1 ]; then
		cmdchain+="-c:v copy -c:a copy "
		mapCount=1
	fi
	
	if [ $isSTT_en == 1 ]; then
		cmdchain+="-c:s mov_text "
	fi
	
	if [ $isSTT_ja == 1 ]; then
		cmdchain+="-c:s mov_text "
	fi
	
	local metadata_langcount=0
	
	if [ $isSTT_en == 1 ]; then
		cmdchain+="-metadata:s:s:$metadata_langcount language=eng "
		metadata_langcount=`expr $metadata_langcount + 1`
	fi
	
	if [ $isSTT_ja == 1 ]; then
		cmdchain+="-metadata:s:s:$metadata_langcount language=jpn "
	fi
	
	if [ -e "$final_video_path" ] && [[ `videoCodecName $final_video_path` == "hevc" ]]; then
		cmdchain+="-vtag hvc1 "
	fi
	
	cmdchain+="\"$session_name.mp4\""
	
	echo $cmdchain
	eval "$cmdchain"

# Note: ffmpeg command line
# 	ffmpeg \
# 	-i $remux_hevc_path \
# 	-i $audio_outpath \
# 	-i $stt_path_en \
# 	-i $stt_path_ja \
# 	-map 0 -map 1 -map 2 -map 3 \
# 	-c:v copy -c:a copy -c:s mov_text -c:s mov_text \
# 	-metadata:s:s:0 language=eng \
# 	-metadata:s:s:1 language=jpn \
# 	"$session_name.mp4"
}

# Delete intermediate files
function postprocess () {
	rm -f $main_hls_path
	rm -f $remux_hevc_path
	rm -f "video_track1.hvc"
	rm -f $audio_outpath
	rm -f $video_outpath
	rm -f $hvc_path
	
	## Keep subtitles or not
	#rm -f $stt_path_en
	#rm -f $stt_path_ja
}

# ---------------------------------------

# Default message
if [ $# != 1 ]; then
	echo "wwdcdl <https://developer.apple.com/videos/play/wwdc20xx/00000/>"
	exit 1
fi

input_url=$1
url=${input_url%/}

# Session ID
session_id=${url##*/}

# Session name
session_title_part=`getHTMLTitle $url`
session_name="$session_id - $session_title_part"

# ---------------------------------------

# Make working directory
mkdir "$session_name"
cd ./"$session_name"

echo "========================================"
echo "[$session_name]"
echo $url
echo $hls_base_url
echo "Working dir: "`pwd`
echo "========================================"

# Extract HLS URL from HTML
hls_url=$(curl -fsSL $url | grep '<video.*src="https:\/\/.*.m3u8".*>' | sed 's/.*\(https:\/\/.*.m3u8\).*/\1/g')

hls_base_url=${hls_url%/*}

# Get HLS m3u8
curl -so $main_hls_path $hls_url

# ---------------------------------------

getURIs
dlprocess
joinFiles
# postprocess

open "$session_name"
