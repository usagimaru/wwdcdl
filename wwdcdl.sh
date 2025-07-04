#!/bin/sh

# Intermediate output files
main_hls_path="cmaf.m3u8"
video_outpath="tmp_video.mp4"
remux_hevc_path="tmp_remux_hevc.mp4"
final_video_path=$video_outpath
audio_outpath="tmp_audio.m4a"

# Subtitles
stt_outpath_en="tmp_stt_en.vtt"
stt_outpath_ja="tmp_stt_ja.vtt"

video_hvc_uri=""
video_avc_uri=""
audio_uri=""
stt_uri_en=""
stt_uri_ja=""
slide_uri=""

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
	local vcodec=`ffprobe -hide_banner -i $1 -show_streams -v error -print_format json | jq '.streams[] | select(.codec_type == "video") | .codec_name' | xargs`
	echo "$vcodec"
}

# Get audio condec name
function audioCodecName () {
	local acodec=`ffprobe -hide_banner -i $1 -show_streams -v error -print_format json | jq '.streams[] | select(.codec_type == "audio") | .codec_name' | xargs`
	echo "$acodec"
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
	video_hvc_uri=`cat $main_hls_path | grep ".m3u8" | grep "^cmaf/hvc" | sort -fVr | grep -m 1 ".*"`
	
	# AVC URI
	video_avc_uri=`cat $main_hls_path | grep ".m3u8" | grep "^cmaf/avc" | sort -fVr | grep -m 1 ".*"`
	
	# Audio URI
	# The number of channels is fixed to stereo to exclude Dolby-Atmos. (grep "CHANNELS=\"2\"")
	# Currently Dolby-Atmos audio is not supported in this script because I have not found a way to properly mux them to QuickTime compatible mp4 format.
	audio_uri=`cat $main_hls_path | grep ".m3u8" | grep "EXT-X-MEDIA:TYPE=AUDIO" | grep "NAME=\"English\"" | grep "CHANNELS=\"2\"" | sort -fVr | grep -m 1 ".*" | sed -E "s/.*URI=\"(.*\.m3u8)\".*/\1/"`
	
	# Subtitle URI en
	stt_uri_en=`cat $main_hls_path | grep ".m3u8" | grep "EXT-X-MEDIA:TYPE=SUBTITLES" | grep -i "LANGUAGE=\"en\"" | grep -iv "subsC" | sed -E "s/.*URI=\"(.*\.m3u8)\".*/\1/"`
	
	if [ ! $stt_uri_en ]; then
		stt_uri_en=`cat $main_hls_path | grep ".m3u8" | grep "EXT-X-MEDIA:TYPE=SUBTITLES" | grep -i "name=\"English\"" | grep -iv "subsC" | sed -E "s/.*URI=\"(.*\.m3u8)\".*/\1/"`
	fi
	
	# Subtitle URI ja
	stt_uri_ja=`cat $main_hls_path | grep ".m3u8" | grep "EXT-X-MEDIA:TYPE=SUBTITLES" | grep -i "LANGUAGE=\"ja\"" | grep -iv "subsC" | sed -E "s/.*URI=\"(.*\.m3u8)\".*/\1/"`
	
	if [ ! $stt_uri_ja ]; then
		stt_uri_ja=`cat $main_hls_path | grep ".m3u8" | grep "EXT-X-MEDIA:TYPE=SUBTITLES" | grep -i "name=\"日本語\"" | grep -iv "subsC" | sed -E "s/.*URI=\"(.*\.m3u8)\".*/\1/"`
	fi
	
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
	# Slide URI
	local slide_url=`curl -fsSL $input_url | grep -i ".*\.pdf" | sed -E "s/.*href=\"([^\"]*).*/\1/"`
	curl -O $slide_url
	
	
	# Prepare URLs
	
	local video_url=$hls_base_url/$video_avc_uri
	if [ -n "$video_hvc_uri" ]; then
		if [[ "$audio_uri" =~ ^https:\/\/.* ]]; then
			# URIがフルURLの場合はそのまま利用
			video_url=$video_hvc_uri
		else
			# URIがパスの場合はベースURLと結合
			video_url=$hls_base_url/$video_hvc_uri
		fi
	fi
	
	local audio_url=""
	if [ -n "$audio_uri" ]; then
		if [[ "$audio_uri" =~ ^https:\/\/.* ]]; then
			audio_url=$audio_uri
		else
			audio_url=$hls_base_url/$audio_uri
		fi
	fi
	
	local stt_url_en=""
	if [ -n "$stt_uri_en" ]; then
		if [[ "$stt_uri_en" =~ ^https:\/\/.* ]]; then
			stt_url_en=$stt_uri_en
		else
			stt_url_en=$hls_base_url/$stt_uri_en
		fi
	fi
	
	local stt_url_ja=""
	if [ -n "$stt_uri_ja" ]; then
		if [[ "$stt_uri_ja" =~ ^https:\/\/.* ]]; then
			stt_url_ja=$stt_uri_ja
		else
			stt_url_ja=$hls_base_url/$stt_uri_ja
		fi
	fi
	
	
	# Subtitle en
	if [[ `exists_url $stt_url_en` == "exists" ]] && [ ! -e "$stt_outpath_en" ]; then
		ffmpeg -allowed_extensions ALL -i $stt_url_en $stt_outpath_en
	else 
		echo $stt_url_en
		echo `exists_url $stt_url_en`
		echo "pass the stt en downloading"
	fi
	
	# Subtitle ja
	if [[ `exists_url $stt_url_ja` == "exists" ]] && [ ! -e "$stt_outpath_ja" ]; then
		ffmpeg -allowed_extensions ALL -i $stt_url_ja $stt_outpath_ja
	else 
		echo "pass the stt ja downloading"
	fi
	
	# Audio (en)
	if [[ `exists_url $audio_url` == "exists" ]] && [ ! -e "$audio_outpath" ]; then
		ffmpeg -allowed_extensions ALL -i $audio_url -c copy $audio_outpath
	else 
		echo "pass the audio downloading"
	fi
		
	# Video
	echo "Video URL: $video_url"
	if [[ `exists_url $video_url` == "exists" ]] && [ ! -e "$video_outpath" ]; then
		local cmd="ffmpeg -allowed_extensions ALL -i $video_url -c copy $video_outpath"
		#echo $cmd
		eval $cmd
	else
		echo "pass the video downloading" 
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
	
	local videoCodecName=`videoCodecName $final_video_path`
	local audioCodecName=`audioCodecName $final_video_path`
	
	if [ -e "$final_video_path" ]; then
		cmdchain+="-i $final_video_path "
		isVideo=1
	fi
	
	if [ -e "$audio_outpath" ]; then
		cmdchain+="-i $audio_outpath "
		isAudio=1
	fi
	
	if [ -e "$stt_outpath_en" ]; then
		cmdchain+="-i $stt_outpath_en "
		isSTT_en=1
	fi
	
	if [ -e "$stt_outpath_ja" ]; then
		cmdchain+="-i $stt_outpath_ja "
		isSTT_ja=1
	fi
	
	
	local mapCount=0
	if [ $isVideo == 1 ]; then
		cmdchain+="-map $mapCount:v "
	fi
	
	if [ $isAudio == 1 ]; then
		mapCount=`expr $mapCount + 1`
		cmdchain+="-map $mapCount:a "
	elif [ "$audioCodecName" == "aac" ]; then
		cmdchain+="-map $mapCount:a "
	fi
	
	if [ $isSTT_en == 1 ]; then
		mapCount=`expr $mapCount + 1`
		cmdchain+="-map $mapCount "
	fi
	
	if [ $isSTT_ja == 1 ]; then
		mapCount=`expr $mapCount + 1`
		cmdchain+="-map $mapCount "
	fi
	
	mapCount=0
	
	if [ $isVideo == 1 ]; then
		cmdchain+="-c:v copy "
	fi
	
	if [ $isAudio == 1 ]; then
		mapCount=`expr $mapCount + 1`
		cmdchain+="-c:a copy "
	elif [ "$audioCodecName" == "aac" ]; then
		cmdchain+="-c:a copy "
	fi
	
	if [ $isSTT_en == 1 ]; then
		mapCount=`expr $mapCount + 1`
		cmdchain+="-c:s mov_text "
	fi
	
	if [ $isSTT_ja == 1 ]; then
		mapCount=`expr $mapCount + 1`
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
	
	if [ "${videoCodecName}" == "hevc" ]; then
		cmdchain+="-vtag hvc1 "
	fi
	
	cmdchain+="\"$session_name.mp4\""
	
	echo $cmdchain
	eval "$cmdchain"

# Note: ffmpeg command line
# 	ffmpeg \
# 	-i $remux_hevc_path \
# 	-i $audio_outpath \
# 	-i $stt_outpath_en \
# 	-i $stt_outpath_ja \
# 	-map 0 -map 1 -map 2 -map 3 \
# 	-c:v copy -c:a copy -c:s mov_text -c:s mov_text \
# 	-metadata:s:s:0 language=eng \
# 	-metadata:s:s:1 language=jpn \
# 	"$session_name.mp4"
}

# Delete intermediate files
function postprocess () {
	trash $main_hls_path > /dev/null 2>&1
	trash $remux_hevc_path > /dev/null 2>&1
	trash "${video_outpath%.*}_track1.hvc" > /dev/null 2>&1
	trash $audio_outpath > /dev/null 2>&1
	trash $video_outpath > /dev/null 2>&1
	trash $hvc_path > /dev/null 2>&1
	
	## Keep subtitles or not
	#rm -f $stt_outpath_en
	#rm -f $stt_outpath_ja
}

# ---------------------------------------

# Default message
if [ $# != 1 ]; then
	echo "wwdcdl.sh <https://developer.apple.com/videos/play/wwdc20xx/00000/>"
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

echo "HLS URL: $hls_url"
echo "Base URL: $hls_base_url"

# Get HLS m3u8
curl -so $main_hls_path $hls_url

# ---------------------------------------

getURIs
dlprocess
joinFiles
postprocess

cd ../
open "$session_name"
