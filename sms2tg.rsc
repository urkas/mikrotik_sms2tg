# sms2tg.rsc - one file import (RouterOS 7.x)
# Installs script sms2tg (export-style) + scheduler 30s + /SMS folder

:do { /file make-directory name="SMS"; } on-error={}
:do { /system script remove [find where name="sms2tg"]; } on-error={}
:do { /system scheduler remove [find where name="sms2tg"]; } on-error={}

/system script
add dont-require-permissions=no name=sms2tg policy=\
    reboot,read,write,policy,test,sensitive source="#\
    \_=========================\
    \n# sms2tg: SMS -> Telegram (concat glue) + ARCHIVE to /file/SMS\
    \n# Deletes SMS from modem inbox after archiving\
    \n# =========================\
    \n\
    \n:local P \"sms2tg:\";\
    \n\
    \n:do {\
    \n\
    \n# === \D0\9D\D0\90\D0\A1\D0\A2\D0\A0\D0\9E\D0\99\D0\9A\D0\98 ===\
    \n:local smsNum \"PUT_MODEM_PHONE_NUM_HERE\";\
    \n:local resetFromList \"PUT_YOUR_PHONE_NUM_HERE\";\
    \n:local tgToken \"PUT_TELEGRAM_BOT_TOKEN_HERE\";\
    \n:local tgChatId \"PUT_TELEGRAM_CHAT_ID_HERE\";\
    \n:local smsPort \"lte1\";\
    \n:local apiUrl (\"https://api.telegram.org/bot\" . \$tgToken . \"/sendMes\
    sage\");\
    \n\
    \n:local mtName [/system identity get name];\
    \n:if ([:len \$mtName] = 0) do={ :set mtName \"MikroTik\"; }\
    \n\
    \n# --- enable sms ---\
    \n/tool sms set port=\$smsPort receive-enabled=yes;\
    \n\
    \n# --- ensure folder SMS ---\
    \n:do { /file make-directory name=\"SMS\"; } on-error={\
    \n    :do { /file add name=\"SMS\" type=directory; } on-error={}\
    \n};\
    \n\
    \n:local nowDate [/system clock get date];\
    \n:local nowTime [/system clock get time];\
    \n\
    \n# ===== helpers =====\
    \n:local hex2dec do={ :return [:tonum (\"0x\" . \$1)]; };\
    \n\
    \n:local onlyHex do={\
    \n    :local s \$1; :local out \"\"; :local i 0; :local n [:len \$s];\
    \n    :local hexd \"0123456789abcdefABCDEF\";\
    \n    :while (\$i < \$n) do={\
    \n        :local c [:pick \$s \$i (\$i+1)];\
    \n        :if ([:typeof [:find \$hexd \$c]] != \"nil\") do={ :set out (\$o\
    ut . \$c); }\
    \n        :set i (\$i + 1);\
    \n    }\
    \n    :return \$out;\
    \n};\
    \n\
    \n:local digitsOnly do={\
    \n    :local s \$1; :local out \"\"; :local i 0; :local n [:len \$s];\
    \n    :local dig \"0123456789\";\
    \n    :while (\$i < \$n) do={\
    \n        :local c [:pick \$s \$i (\$i+1)];\
    \n        :if ([:typeof [:find \$dig \$c]] != \"nil\") do={ :set out (\$ou\
    t . \$c); }\
    \n        :set i (\$i + 1);\
    \n    }\
    \n    :return \$out;\
    \n};\
    \n\
    \n:local safeName do={\
    \n    :local s \$1; :local out \"\"; :local i 0; :local n [:len \$s];\
    \n    :local ok \"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123\
    456789_-\";\
    \n    :while (\$i < \$n) do={\
    \n        :local c [:pick \$s \$i (\$i+1)];\
    \n        :if ((\$c=\" \") || (\$c=\"/\") || (\$c=\":\") || (\$c=\".\") ) \
    do={\
    \n            :set out (\$out . \"_\");\
    \n        } else={\
    \n            :if ([:typeof [:find \$ok \$c]] != \"nil\") do={ :set out (\
    \$out . \$c); }\
    \n        }\
    \n        :set i (\$i + 1);\
    \n    }\
    \n    :return \$out;\
    \n};\
    \n\
    \n:local jsonSafe do={\
    \n    :local s \$1; :local out \"\"; :local i 0; :local n [:len \$s];\
    \n    :while (\$i < \$n) do={\
    \n        :local c [:pick \$s \$i (\$i+1)];\
    \n        :if (\$c=\"\\\\\") do={ :set out (\$out . \"\\\\u005C\"); } else\
    ={\
    \n        :if (\$c=\"\\\"\") do={ :set out (\$out . \"\\\\u0022\"); } else\
    ={\
    \n        :if (\$c=\"\\r\") do={ :set out (\$out . \"\\\\u000D\"); } else=\
    {\
    \n        :if (\$c=\"\\n\") do={ :set out (\$out . \"\\\\u000A\"); } else=\
    {\
    \n        :if (\$c=\"\\t\") do={ :set out (\$out . \"\\\\u0009\"); } else=\
    {\
    \n            :set out (\$out . \$c);\
    \n        }}}}};\
    \n        :set i (\$i + 1);\
    \n    }\
    \n    :return \$out;\
    \n};\
    \n\
    \n:local fileSafe do={\
    \n    :local s \$1; :local out \"\"; :local i 0; :local n [:len \$s];\
    \n    :while (\$i < \$n) do={\
    \n        :local c [:pick \$s \$i (\$i+1)];\
    \n        :if (\$c=\"\\r\") do={ :set out (\$out . \"\\\\r\"); } else={\
    \n        :if (\$c=\"\\n\") do={ :set out (\$out . \"\\\\n\"); } else={\
    \n            :set out (\$out . \$c);\
    \n        }};\
    \n        :set i (\$i + 1);\
    \n    }\
    \n    :return \$out;\
    \n};\
    \n\
    \n:local unFileSafe do={\
    \n    :local s \$1; :local out \"\"; :local i 0; :local n [:len \$s];\
    \n    :while (\$i < \$n) do={\
    \n        :local c [:pick \$s \$i (\$i+1)];\
    \n        :if ((\$c=\"\\\\\") && ((\$i+1) < \$n)) do={\
    \n            :local c2 [:pick \$s (\$i+1) (\$i+2)];\
    \n            :if (\$c2=\"n\") do={ :set out (\$out . \"\\n\"); :set i (\$\
    i + 2); } else={\
    \n            :if (\$c2=\"r\") do={ :set out (\$out . \"\\r\"); :set i (\$\
    i + 2); } else={\
    \n                :set out (\$out . \$c);\
    \n                :set i (\$i + 1);\
    \n            }};\
    \n        } else={\
    \n            :set out (\$out . \$c);\
    \n            :set i (\$i + 1);\
    \n        }\
    \n    }\
    \n    :return \$out;\
    \n};\
    \n\
    \n:local ucs2ToEsc do={\
    \n    :local hex \$1; :local out \"\"; :local i 0; :local n [:len \$hex];\
    \n    :while ((\$i + 4) <= \$n) do={\
    \n        :set out (\$out . \"\\\\u\" . [:pick \$hex \$i (\$i+4)]);\
    \n        :set i (\$i + 4);\
    \n    }\
    \n    :return \$out;\
    \n};\
    \n\
    \n:local getKV do={\
    \n    :local data (\$1 . \"\\n\");\
    \n    :local key (\$2 . \"=\");\
    \n    :local p [:find \$data \$key];\
    \n    :if ([:typeof \$p] = \"nil\") do={ :return \"\"; }\
    \n    :local s (\$p + [:len \$key]);\
    \n    :local e [:find \$data \"\\n\" \$s];\
    \n    :return [:pick \$data \$s \$e];\
    \n};\
    \n\
    \n:local setKV do={\
    \n    :local content \$1; :local k \$2; :local v \$3;\
    \n    :local probe (\$content . \"\\n\");\
    \n    :local key (\$k . \"=\");\
    \n    :local p [:find \$probe \$key];\
    \n\
    \n    :if ([:typeof \$p] = \"nil\") do={\
    \n        :if ([:len \$content] = 0) do={ :return (\$k . \"=\" . \$v); }\
    \n        :return (\$content . \"\\n\" . \$k . \"=\" . \$v);\
    \n    }\
    \n\
    \n    :local lineEnd [:find \$probe \"\\n\" \$p];\
    \n    :local before [:pick \$probe 0 \$p];\
    \n\
    \n    :local afterStart (\$lineEnd + 1);\
    \n    :local after [:pick \$probe \$afterStart [:len \$probe]];\
    \n\
    \n    :local out (\$before . \$k . \"=\" . \$v);\
    \n    :if ([:len \$after] > 0) do={ :set out (\$out . \"\\n\" . \$after); \
    }\
    \n\
    \n    :local outLen [:len \$out];\
    \n    :if (\$outLen > 0) do={\
    \n        :local lastChar [:pick \$out (\$outLen-1) \$outLen];\
    \n        :if (\$lastChar = \"\\n\") do={ :set out [:pick \$out 0 (\$outLe\
    n-1)]; }\
    \n    }\
    \n\
    \n    :return \$out;\
    \n};\
    \n\
    \n:local tgSend do={\
    \n    :local url \$1;\
    \n    :local chatId \$2;\
    \n    :local textEsc \$3;\
    \n\
    \n    :local json (\"{\\\"chat_id\\\":\\\"\" . \$chatId . \"\\\",\\\"text\
    \\\":\\\"\" . \$textEsc . \"\\\"}\");\
    \n\
    \n    :do {\
    \n        /tool fetch mode=https url=\$url http-method=post http-header-fi\
    eld=\"Content-Type: application/json\" http-data=\$json check-certificate=\
    no keep-result=no;\
    \n        :return true;\
    \n    } on-error={\
    \n        :log error (\$P . \" fetch error: \" . \$message);\
    \n        :return false;\
    \n    };\
    \n};\
    \n\
    \n:local writeFile do={\
    \n    :local fname \$1;\
    \n    :local body  \$2;\
    \n    :local f [/file find where name=\$fname];\
    \n    :if ([:len \$f] = 0) do={ /file add name=\$fname; :set f [/file find\
    \_where name=\$fname]; }\
    \n    /file set \$f contents=\$body;\
    \n};\
    \n\
    \n# ===== 1) inbox -> buffer / single =====\
    \n:foreach id in=[/tool sms inbox find] do={\
    \n\
    \n    :local from [/tool sms inbox get \$id phone];\
    \n    :local ts   [/tool sms inbox get \$id timestamp];\
    \n    :local msg0 [/tool sms inbox get \$id message];\
    \n    :local pdu0 [/tool sms inbox get \$id pdu];\
    \n    :local pdu  [\$onlyHex \$pdu0];\
    \n\
    \n    :local dcsHex \"\";\
    \n    :local udHex  \"\";\
    \n    :local msgEsc \"\";\
    \n    :local fo 0;\
    \n\
    \n    :local isConcat false;\
    \n    :local cref \"\";\
    \n    :local ctot 1;\
    \n    :local cseq 1;\
    \n\
    \n    :local doResetPart false;\
    \n\
    \n    :do {\
    \n        :local p 0;\
    \n\
    \n        :local smscLen [\$hex2dec [:pick \$pdu 0 2]];\
    \n        :local pduLen [:len \$pdu];\
    \n        :local smscSkip ((\$smscLen + 1) * 2);\
    \n        :if ((\$smscLen <= 20) && (\$smscSkip <= \$pduLen)) do={ :set p \
    \$smscSkip; }\
    \n\
    \n        :set fo [\$hex2dec [:pick \$pdu \$p (\$p+2)]];\
    \n        :set p (\$p + 2);\
    \n\
    \n        :local oaLen [\$hex2dec [:pick \$pdu \$p (\$p+2)]];\
    \n        :set p (\$p + 2);\
    \n\
    \n        :set p (\$p + 2); # type-of-address\
    \n        :local oaOctets ((\$oaLen + 1) / 2);\
    \n        :set p (\$p + (\$oaOctets * 2));\
    \n\
    \n        :set p (\$p + 2); # PID\
    \n        :set dcsHex [:pick \$pdu \$p (\$p+2)];\
    \n        :set p (\$p + 2);\
    \n\
    \n        :set p (\$p + 14); # SCTS\
    \n\
    \n        :local udl [\$hex2dec [:pick \$pdu \$p (\$p+2)]];\
    \n        :set p (\$p + 2);\
    \n\
    \n        :local udEnd (\$p + (\$udl * 2));\
    \n        :if (\$udEnd > \$pduLen) do={ :set udEnd \$pduLen; }\
    \n        :set udHex [:pick \$pdu \$p \$udEnd];\
    \n\
    \n        :local udHexLen [:len \$udHex];\
    \n\
    \n        # UDH concat\
    \n        :if (((\$fo % 128) >= 64) && (\$udHexLen >= 2)) do={\
    \n            :local udhLen [\$hex2dec [:pick \$udHex 0 2]];\
    \n            :local cut ((\$udhLen + 1) * 2);\
    \n            :if (\$cut > \$udHexLen) do={ :set cut \$udHexLen; }\
    \n\
    \n            :local udhAll [:pick \$udHex 0 \$cut];\
    \n\
    \n            :local p0 [:find \$udhAll \"0003\"];\
    \n            :if ([:typeof \$p0] != \"nil\") do={\
    \n                :set cref [:pick \$udhAll (\$p0+4) (\$p0+6)];\
    \n                :set ctot [\$hex2dec [:pick \$udhAll (\$p0+6) (\$p0+8)]]\
    ;\
    \n                :set cseq [\$hex2dec [:pick \$udhAll (\$p0+8) (\$p0+10)]\
    ];\
    \n                :if (\$ctot > 1) do={ :set isConcat true; }\
    \n            } else={\
    \n                :local p8 [:find \$udhAll \"0804\"];\
    \n                :if ([:typeof \$p8] != \"nil\") do={\
    \n                    :set cref [:pick \$udhAll (\$p8+4) (\$p8+8)];\
    \n                    :set ctot [\$hex2dec [:pick \$udhAll (\$p8+8) (\$p8+\
    10)]];\
    \n                    :set cseq [\$hex2dec [:pick \$udhAll (\$p8+10) (\$p8\
    +12)]];\
    \n                    :if (\$ctot > 1) do={ :set isConcat true; }\
    \n                }\
    \n            }\
    \n\
    \n            :set udHex [:pick \$udHex \$cut [:len \$udHex]];\
    \n        }\
    \n\
    \n        # decode / RESET detect\
    \n        :if ((\$dcsHex = \"08\") && ([:len \$udHex] > 0)) do={\
    \n            :set msgEsc [\$ucs2ToEsc \$udHex];\
    \n            :if ([:typeof [:find \$udHex \"00520045005300450054\"]] != \
    \"nil\") do={ :set doResetPart true; }\
    \n        } else={\
    \n            :set msgEsc [\$jsonSafe \$msg0];\
    \n            :if ([:typeof [:find \$msg0 \"RESET\"]] != \"nil\") do={ :se\
    t doResetPart true; }\
    \n        }\
    \n\
    \n    } on-error={\
    \n        :set isConcat false;\
    \n        :set cref \"\";\
    \n        :set ctot 1;\
    \n        :set cseq 1;\
    \n        :set msgEsc [\$jsonSafe \$msg0];\
    \n    };\
    \n\
    \n    # RESET allowed\?\
    \n    :local resetAllowed false;\
    \n    :if ([:typeof [:find (\",\" . \$resetFromList . \",\") (\",\" . \$fr\
    om . \",\")]] != \"nil\") do={ :set resetAllowed true; }\
    \n\
    \n    # --- multipart: buffer into /file/SMS and delete part from modem --\
    -\
    \n    :if (\$isConcat && ([:len \$cref] > 0) && (\$ctot > 1) && (\$cseq >=\
    \_1) && (\$cseq <= \$ctot)) do={\
    \n\
    \n        :local fromDigits [\$digitsOnly \$from];\
    \n        :local bufName (\"SMS/smsbufc_\" . \$fromDigits . \"_\" . \$cref\
    \_. \".txt\");\
    \n\
    \n        :local fId [/file find where name=\$bufName];\
    \n        :if ([:len \$fId] = 0) do={ /file add name=\$bufName; :set fId [\
    /file find where name=\$bufName]; }\
    \n\
    \n        :local cont [/file get \$fId contents];\
    \n\
    \n        :if ([:len [\$getKV \$cont \"FROMRAW\"]] = 0) do={ :set cont [\$\
    setKV \$cont \"FROMRAW\" [\$fileSafe \$from]]; }\
    \n        :if ([:len [\$getKV \$cont \"FROMD\"]] = 0)   do={ :set cont [\$\
    setKV \$cont \"FROMD\" \$fromDigits]; }\
    \n        :if ([:len [\$getKV \$cont \"CREF\"]] = 0)    do={ :set cont [\$\
    setKV \$cont \"CREF\" \$cref]; }\
    \n        :if ([:len [\$getKV \$cont \"TS\"]] = 0)      do={ :set cont [\$\
    setKV \$cont \"TS\" [\$fileSafe \$ts]]; }\
    \n        :if ([:len [\$getKV \$cont \"TOTAL\"]] = 0)   do={ :set cont [\$\
    setKV \$cont \"TOTAL\" \$ctot]; }\
    \n\
    \n        :if (\$doResetPart && \$resetAllowed) do={ :set cont [\$setKV \$\
    cont \"RESET\" \"1\"]; }\
    \n\
    \n        :local kE (\"P\" . \$cseq . \"E\");\
    \n        :local kP (\"P\" . \$cseq . \"P\");\
    \n\
    \n        :if ([:len [\$getKV \$cont \$kE]] = 0) do={ :set cont (\$cont . \
    \"\\n\" . \$kE . \"=\" . \$msgEsc); }\
    \n        :if ([:len [\$getKV \$cont \$kP]] = 0) do={ :set cont (\$cont . \
    \"\\n\" . \$kP . \"=\" . [\$fileSafe \$msg0]); }\
    \n\
    \n        /file set \$fId contents=\$cont;\
    \n\
    \n        # delete SMS-part from modem memory\
    \n        :do { /tool sms inbox remove \$id; } on-error={};\
    \n\
    \n    } else={\
    \n\
    \n        # --- single: archive -> delete from modem -> send TG ---\
    \n        :local fn (\"SMS/sms_\" . [\$safeName \$nowDate] . \"_\" . [\$sa\
    feName \$nowTime] . \"_from\" . [\$digitsOnly \$from] . \"_id\" . \$id . \
    \".txt\");\
    \n        :local arch (\"MikroTik: \" . \$mtName . \"\\nPhone: \" . \$smsN\
    um . \"\\nFrom: \" . \$from . \"\\nTime: \" . \$ts . \"\\n\\n\" . \$msg0);\
    \n        [\$writeFile \$fn \$arch];\
    \n\
    \n        :do { /tool sms inbox remove \$id; } on-error={};\
    \n\
    \n        :local textEsc (\"MikroTik: \" . [\$jsonSafe \$mtName] . \"\\\\u\
    000APhone: \" . [\$jsonSafe \$smsNum] . \"\\\\u000ASMS\\\\u000AFrom: \" . \
    [\$jsonSafe \$from] . \"\\\\u000ATime: \" . [\$jsonSafe \$ts] . \"\\\\u000\
    A\\\\u000A\" . \$msgEsc);\
    \n\
    \n        :if (![\$tgSend \$apiUrl \$tgChatId \$textEsc]) do={\
    \n            :log error (\$P . \" send failed single (archived) id=\" . \
    \$id);\
    \n        }\
    \n\
    \n        :if (\$doResetPart && \$resetAllowed) do={ :delay 3; /system reb\
    oot; }\
    \n    }\
    \n}\
    \n\
    \n# ===== 2) send completed buffers (do not delete buffers inside loop) ==\
    ===\
    \n:local delFiles \"\";\
    \n:local needReboot false;\
    \n\
    \n:foreach fid in=[/file find where name~\"SMS/smsbufc_\"] do={\
    \n\
    \n    :local cont [/file get \$fid contents];\
    \n    :local totalStr [\$getKV \$cont \"TOTAL\"];\
    \n    :if ([:len \$totalStr] = 0) do={ :continue; }\
    \n\
    \n    :local total [:tonum \$totalStr];\
    \n    :local complete true;\
    \n\
    \n    :for i from=1 to=\$total do={\
    \n        :local kE (\"P\" . \$i . \"E\");\
    \n        :if ([:len [\$getKV \$cont \$kE]] = 0) do={ :set complete false;\
    \_}\
    \n    }\
    \n\
    \n    :if (\$complete) do={\
    \n\
    \n        :local fromRaw [\$unFileSafe [\$getKV \$cont \"FROMRAW\"]];\
    \n        :local fromDigits [\$getKV \$cont \"FROMD\"];\
    \n        :local cref [\$getKV \$cont \"CREF\"];\
    \n        :local tsBuf  [\$unFileSafe [\$getKV \$cont \"TS\"]];\
    \n        :local resetBuf [\$getKV \$cont \"RESET\"];\
    \n\
    \n        :local fullEsc \"\";\
    \n        :local fullPlain \"\";\
    \n\
    \n        :for i from=1 to=\$total do={\
    \n            :local kE2 (\"P\" . \$i . \"E\");\
    \n            :local kP2 (\"P\" . \$i . \"P\");\
    \n            :set fullEsc (\$fullEsc . [\$getKV \$cont \$kE2]);\
    \n            :set fullPlain (\$fullPlain . [\$unFileSafe [\$getKV \$cont \
    \$kP2]]);\
    \n        }\
    \n\
    \n        :local textEsc (\"MikroTik: \" . [\$jsonSafe \$mtName] . \"\\\\u\
    000APhone: \" . [\$jsonSafe \$smsNum] . \"\\\\u000ASMS\\\\u000AFrom: \" . \
    [\$jsonSafe \$fromRaw] . \"\\\\u000ATime: \" . [\$jsonSafe \$tsBuf] . \"\\\
    \\u000A\\\\u000A\" . \$fullEsc);\
    \n\
    \n        :local ok [\$tgSend \$apiUrl \$tgChatId \$textEsc];\
    \n\
    \n        :if (\$ok) do={\
    \n\
    \n            :local fn2 (\"SMS/sms_\" . [\$safeName \$nowDate] . \"_\" . \
    [\$safeName \$nowTime] . \"_from\" . \$fromDigits . \"_ref\" . \$cref . \"\
    .txt\");\
    \n            :local arch2 (\"MikroTik: \" . \$mtName . \"\\nPhone: \" . \
    \$smsNum . \"\\nFrom: \" . \$fromRaw . \"\\nTime: \" . \$tsBuf . \"\\n\\n\
    \" . \$fullPlain);\
    \n            [\$writeFile \$fn2 \$arch2];\
    \n\
    \n            :local fname [/file get \$fid name];\
    \n            :if ([:len \$delFiles] = 0) do={ :set delFiles \$fname; } el\
    se={ :set delFiles (\$delFiles . \",\" . \$fname); }\
    \n\
    \n            :if (\$resetBuf=\"1\") do={ :set needReboot true; }\
    \n\
    \n        } else={\
    \n            :log error (\$P . \" send failed multipart (buffer kept) fil\
    e=\" . [/file get \$fid name]);\
    \n        }\
    \n    }\
    \n}\
    \n\
    \n# ===== delete buffers after loop =====\
    \n:if ([:len \$delFiles] > 0) do={\
    \n    :local s (\$delFiles . \",\");\
    \n    :local p 0;\
    \n    :local sl [:len \$s];\
    \n    :while (\$p < \$sl) do={\
    \n        :local c [:find \$s \",\" \$p];\
    \n        :if ([:typeof \$c] = \"nil\") do={ :set c \$sl; }\
    \n        :local nm [:pick \$s \$p \$c];\
    \n        :if ([:len \$nm] > 0) do={ :do { /file remove [find where name=\
    \$nm]; } on-error={}; }\
    \n        :set p (\$c + 1);\
    \n    }\
    \n}\
    \n\
    \n:if (\$needReboot) do={ :delay 3; /system reboot; }\
    \n\
    \n\
    \n\
    \n} on-error={\
    \n    :local em \$message;\
    \n    :if ([:typeof \$em] = \"nil\") do={ :set em \"\"; }\
    \n    :if ([:len \$em] = 0) do={ :set em \"unknown\"; }\
    \n    :log error (\$P . \" FATAL: \" . \$em);\
    \n}\
    \n"

/system scheduler
add name=sms2tg disabled=yes interval=00:00:30 start-time=00:00:00 on-event="/system script run sms2tg" policy=reboot,read,write,policy,test,sensitive

:log warning "sms2tg: installed (script + scheduler 30s)"
