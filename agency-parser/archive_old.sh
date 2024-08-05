#!/bin/bash
SCRIPT_DIR="$(dirname "$0")";
source ${SCRIPT_DIR}/../commons/commons.sh

#setIsCI;
#
#setGitCommitEnabled;
#
#setGitUser;
#
echo ">> Archiving GTFS... '$*'"
#GTFS_FILE="${SCRIPT_DIR}/input/gtfs.zip";
#FILES_DIR="${SCRIPT_DIR}/input/gtfs";
GTFS_FILE=$1;
FILES_DIR=$2;

if [[ ! -f "${GTFS_FILE}" ]]; then
  echo "ERROR: GTFS file not found in ${FILES_DIR}";
  exit 1;
fi

if [[ -d ${FILES_DIR} ]]; then
	rm -r ${FILES_DIR};
	checkResult $? false;
fi
unzip -j ${GTFS_FILE} -d ${FILES_DIR};
checkResult $? false;

if [[ ! -d "${FILES_DIR}" ]]; then
  echo "ERROR: GTFS files directory not found in ${FILES_DIR}";
  exit 1;
fi

START_DATE=""
END_DATE=""
if [[ -f "${FILES_DIR}/calendars.txt" ]]; then
  echo "TODO: Using calendars.txt";
  exit 1
  # TODO
elif [[ -f "${FILES_DIR}/calendar_dates.txt" ]]; then
  echo "- Using calendar_dates.txt";
  # find date column
  HEADERS=$(head -n 1 "${FILES_DIR}/calendar_dates.txt")
#  echo "HEADERS: ${HEADERS}"
#  declare -A HEADERS_ARRAY
  # shellcheck disable=SC2034
  IFS="," read -r -a HEADERS_ARRAY <<< "$HEADERS"
#  echo "HEADERS_ARRAY: ${HEADERS_ARRAY[*]}"
#  echo "HEADERS_ARRAY[date]: ${HEADERS_ARRAY["date"]}"
#  getArrayIndex HEADERS_ARRAY "date";
#  DATE_INDEX=$?
  DATE_INDEX=$(getArrayIndex HEADERS_ARRAY "date")
  checkResult $?;
#  echo "DATE_INDEX: ${DATE_INDEX}"
  CUT_INDEX=$((DATE_INDEX+1))
#  echo "CUT_INDEX: ${CUT_INDEX}"
#  DATES=($(tail -n +2 "${FILES_DIR}/calendar_dates.txt" | cut -d ',' -f $CUT_INDEX))
  mapfile -t DATES < <(tail -n +2 "${FILES_DIR}/calendar_dates.txt" | cut -d ',' -f $CUT_INDEX)
#  echo "DATES: ${DATES[*]}"
  readarray -t DATES_SORTED < <(printf '%s\n' "${DATES[@]}" | sort)
#  echo "DATES_SORTED: ${DATES_SORTED[*]}"
  START_DATE=${DATES_SORTED[0]}
  echo "- start date: ${START_DATE}"
  END_DATE=${DATES_SORTED[-1]}
  echo "- end date: ${END_DATE}"
else
  echo "ERROR: GTFS files not found in ${FILES_DIR}";
  exit 1;
fi

ARCHIVE_DIR="${SCRIPT_DIR}/archive";
echo "- Archive dir: $ARCHIVE_DIR";

YESTERDAY=$(date -d "yesterday" +%Y%m%d); # service can start yesterday and finish today
echo "- Yesterday: $YESTERDAY";

for ZIP_FILE in $(ls -a ${ARCHIVE_DIR}/*.zip) ; do
  echo "--------------------"
  echo "- ZIP file: $ZIP_FILE";
  ZIP_FILE_BASENAME=$(basename "$ZIP_FILE");
  ZIP_FILE_BASENAME_NO_EXT="${ZIP_FILE_BASENAME%.*}";
  ZIP_FILE_BASENAME_NO_EXT_PARTS=(${ZIP_FILE_BASENAME_NO_EXT//-/ });
  ZIP_FILE_START_DATE=${ZIP_FILE_BASENAME_NO_EXT_PARTS[0]};
  ZIP_FILE_END_DATE=${ZIP_FILE_BASENAME_NO_EXT_PARTS[1]};
  echo "- ZIP start date: $ZIP_FILE_START_DATE";
  if [[ "$ZIP_FILE_START_DATE" -lt "$YESTERDAY" && "$ZIP_FILE_END_DATE" -ge "$YESTERDAY" ]]; then
    ZIP_FILE_START_DATE=$YESTERDAY;
    echo "- ZIP start date (yesterday): $ZIP_FILE_START_DATE";
  fi
  echo "- ZIP end date: $ZIP_FILE_END_DATE";
  if [[ "$ZIP_FILE_END_DATE" -lt "$YESTERDAY" && "$ZIP_FILE_END_DATE" -le "$START_DATE" ]]; then
    echo "- ZIP file is entirely in the past and older than new ZIP > REMOVE";
    rm "$ZIP_FILE";
    checkResult $?;
  elif [[ "$ZIP_FILE_START_DATE" -ge "$START_DATE" && "$ZIP_FILE_END_DATE" -le "$END_DATE" ]]; then
    echo "- ZIP file is entirely inside the new ZIP > REMOVE";
    rm "$ZIP_FILE";
    checkResult $?;
  elif [[ "$ZIP_FILE_START_DATE" -gt "$END_DATE" && "$ZIP_FILE_END_DATE" -gt "$YESTERDAY" ]]; then
    echo "- ZIP file is entirely in the future and newer than new ZIP > KEEP";
  else
    echo "TODO handle this case";
  fi
  echo "--------------------"
done

mkdir -p "$ARCHIVE_DIR";

ARCHIVE_FILE="${ARCHIVE_DIR}/${START_DATE}-${END_DATE}.zip";
cp "$GTFS_FILE" "$ARCHIVE_FILE";
checkResult $?;

#if [[ ${MT_GIT_COMMIT_ENABLED} == true ]]; then
#  echo "> Adding ZIP file to git ...";
#  git -C "$ARCHIVE_DIR" add "*.zip";
#  checkResult $? false;
#  git -C "$ARCHIVE_DIR" status -sb;
#else
#  echo "> Git commit NOT enabled.. SKIP";
#fi
#
echo ">> Archiving GTFS... DONE ($ARCHIVE_FILE)"