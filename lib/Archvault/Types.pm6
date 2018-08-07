use v6;
use Archvault::Grammar;
unit module Archvault::Types;

# -----------------------------------------------------------------------------
# constants
# -----------------------------------------------------------------------------

# - keys are valid typed strings
# - values are for dialog menu descriptions and are intentionally
#   quoted twice for passing to dialog

# disktypes {{{

constant %disktypes = Map.new(
    'HDD' => '"Spinning disk drive"',
    'SSD' => '"Solid state disk drive"',
    'USB' => '"USB drive"'
);

# end disktypes }}}
# graphics {{{

constant %graphics = Map.new(
    'INTEL'  => '"Integrated or unknown graphics card"',
    'NVIDIA' => '"Nvidia dedicated/switchable GPU"',
    'RADEON' => '"Radeon dedicated/switchable GPU"'
);

# end graphics }}}
# keymaps {{{

constant %keymaps = Map.new(
    'ANSI-dvorak'              => '"ANSI Dvorak keymap"',
    'amiga-de'                 => '"German keymap for Linux/m68k for Amiga 2000/3000/4000 keyboards"',
    'amiga-us'                 => '"US keymap for Amiga keyboards"',
    'applkey'                  => '"VT220 auxiliary keypad in application mode"',
    'atari-de'                 => '"German kyemap for Atari keyboards"',
    'atari-se'                 => '"Swedish keymap for Atari keyboards"',
    'atari-uk-falcon'          => '"UK Falcon keymap for Atari keyboards"',
    'atari-us'                 => '"US keymap for Atari keyboards"',
    'azerty'                   => '"AZERTY keymap"',
    'backspace'                => '"Ctrl-H backspace keymap"',
    'bashkir'                  => '"Bashkir keymap, CapsLock toggles Cyrillic mode"',
    'be-latin1'                => '"AZERTY keymap"',
    'bg-cp1251'                => '"Bulgarian Phonetic Cyrillic code page 1251 keymap"',
    'bg-cp855'                 => '"Bulgarian Cyrillic keymap"',
    'bg_bds-cp1251'            => '"Linux console Bulgarian keymap, BDS (Bulgarian National Standart) Cyrillic layout"',
    'bg_bds-utf8'              => '"Linux console Bulgarian keymap, BDS (Bulgarian National Standart) Cyrillic layout"',
    'bg_pho-cp1251'            => '"Linux console Bulgarian keymap, phonetic Cyrillic layout"',
    'bg_pho-utf8'              => '"Linux console Bulgarian keymap, phonetic Cyrillic layout"',
    'br-abnt'                  => '"Mapa para teclados ABNT"',
    'br-abnt2'                 => '"Mapa para teclados ABNT2"',
    'br-latin1-abnt2'          => '"Brazilian mapping for Brazilian ABNT2 keyboards"',
    'br-latin1-us'             => '"Brazilian mapping for US international keyboards"',
    'by'                       => '"Bielorussion, Russion, English ISO-8859"',
    'by-cp1251'                => '"Byelorussian CP1251 Cyrillic keymap"',
    'bywin-cp1251'             => '"Byelorussian CP1251 Cyrillic keymap"',
    'carpalx'                  => '"Carpalx keymap"',
    'carpalx-full'             => '"Carpalx full keymap"',
    'cf'                       => '"French-Canadian keyboard"',
    'colemak'                  => '"Colemak keymap for Linux console"',
    'croat'                    => '"Croatian keymap"',
    'ctrl'                     => '"CapsLock Ctrl switch"',
    'cz'                       => '"Klavesova mapa kompatibilni s Windows QWERTY"',
    'cz-cp1250'                => '"Czech Windows CP 1250 keyboard map for text console"',
    'cz-lat2'                  => '"Czech ISO 8859-2 keyboard map for text console"',
    'cz-lat2-prog'             => '"Czech ISO 8859-2 keyboard map for text console"',
    'cz-qwertz'                => '"Klavesova mapa kompatibilni s Windows QWERTZ"',
    'cz-us-qwertz'             => '"Czech ISO 8859-2 keyboard map for text console"',
    'de'                       => '"German QWERTZ keymap"',
    'de-latin1'                => '"German QWERTZ keymap"',
    'de-latin1-nodeadkeys'     => '"German QWERTZ keymap"',
    'de-mobii'                 => '"German QWERTZ keymap"',
    'de_CH-latin1'             => '"Swiss German QWERTZ keymap"',
    'de_alt_UTF-8'             => '"German Mac (Intel) QWERTZ keymap"',
    'defkeymap'                => '"Default QWERTY keymap"',
    'defkeymap_V1'             => '"Default QWERTY keymap"',
    'dk'                       => '"Danish QWERTY keymap"',
    'dk-latin1'                => '"Danish QWERTY keymap with dead accents"',
    'dvorak'                   => '"Dvorak keymap"',
    'dvorak-ca-fr'             => '"Canada - French Dvorak keymap"',
    'dvorak-es'                => '"Spanish Dvorak keymap"',
    'dvorak-fr'                => '"French Dvorak keymap"',
    'dvorak-l'                 => '"Left single-handed Dvorak keymap"',
    'dvorak-la'                => '"Latin American Dvorak keymap"',
    'dvorak-programmer'        => '"Programmer Dvorak keymap"',
    'dvorak-r'                 => '"Right single-handed Dvorak keymap"',
    'dvorak-ru'                => '"Dvorak + Russian layout, CapsLock to toggle"',
    'dvorak-sv-a1'             => '"Swedish version of the Dvorak layout (Svorak)"',
    'dvorak-sv-a5'             => '"Swedish version of the Dvorak layout (Svorak)"',
    'dvorak-uk'                => '"UK Dvorak keymap"',
    'emacs'                    => '"US QWERTY keymap customized for use with Emacs"',
    'emacs2'                   => '"US QWERTY keymap customized for use with Emacs"',
    'es'                       => '"Spanish QWERTY keymap"',
    'es-cp850'                 => '"Teclado español ajustado a la pagina de codigos CP-850"',
    'es-olpc'                  => '"Spanish QWERTY keymap for OLPC"',
    'et'                       => '"Estonian QWERTY keymap"',
    'et-nodeadkeys'            => '"Estonian QWERTY keymap with no dead keys"',
    'euro'                     => '"Euro and cent"',
    'euro1'                    => '"Euro and cent"',
    'euro2'                    => '"Euro and cent"',
    'fi'                       => '"Classic Finnish keymap with ISO-8859-1/ISO-8859-15 symbols"',
    'fr'                       => '"French AZERTY keymap"',
    'fr-bepo'                  => '"Improved ergonomic French keymap using Dvorak method"',
    'fr-bepo-latin9'           => '"Improved ergonomic French keymap using Dvorak method"',
    'fr-latin1'                => '"French AZERTY keymap"',
    'fr-latin9'                => '"French AZERTY keymap"',
    'fr-pc'                    => '"AZERTY keymap for French PC keyboard (non-US 102 keys)"',
    'fr_CH'                    => '"French QWERTZ keymap"',
    'fr_CH-latin1'             => '"French QWERTZ keymap"',
    'gr'                       => '"Improved Greek QWERTY keymap"',
    'gr-pc'                    => '"Greek QWERTY keymap"',
    'hu'                       => '"The standard Hungarian QWERTZ keymap (iso8859-2)"',
    'hu101'                    => '"Hungarian keymap for 101 key keyboards (iso8859-2)"',
    'il'                       => '"Hebrew QWERTY keymap, non-phonetic"',
    'il-heb'                   => '"Hebrew QWERTY keymap, non-phonetic"',
    'il-phonetic'              => '"Hebrew QWERTY keymap, phonetic"',
    'is-latin1'                => '"Icelandic QWERTY keyboard for Latin 1 character set"',
    'is-latin1-us'             => '"Icelandic QWERTY keyboard for Latin 1 character set"',
    'it'                       => '"Italian QWERTY keymap"',
    'it-ibm'                   => '"Keymap for Italian IBM PC keyboards"',
    'it2'                      => '"Italian QWERTY keymap"',
    'jp106'                    => '"Japanese QWERTY keymap for 106 key keyboards"',
    'kazakh'                   => '"Kazakh QWERTY keymap"',
    'keypad'                   => '"Keypad mapping"',
    'ky_alt_sh-UTF-8'          => '"Kirghiz (aka Kyrgyz) QWERTY UTF-8 Standard Console Keyboard"',
    'kyrgyz'                   => '"Kyrgyz QWERTY keymap"',
    'la-latin1'                => '"Latin American QWERTY keyboard"',
    'lt'                       => '"Lithuanian QWERTY keymap for PC 101/102 keyboards"',
    'lt.baltic'                => '"QWERTY keymap for Lithuanian users (Baltic character set)"',
    'lt.l4'                    => '"Lithuanian QWERTY keymap for PC 101/102 keyboards"',
    'lv'                       => '"Latvian QWERTY keymap"',
    'lv-tilde'                 => '"Latvian QWERTY keymap"',
    'mac-be'                   => '"Mac AZERTY keymap"',
    'mac-de-latin1'            => '"German QWERTY keymap"',
    'mac-de-latin1-nodeadkeys' => '"German QWERTY keymap, no dead keys"',
    'mac-de_CH'                => '"Swiss-German QWERTZ keymap for PowerBook G3 (Bronze Series)"',
    'mac-dk-latin1'            => '"Dansk Macintosh QWERTY keymap"',
    'mac-dvorak'               => '"Dvorak keymap for Macintosh"',
    'mac-es'                   => '"Spanish QWERTY keymap for Macintosh"',
    'mac-euro'                 => '"Euro and cent"',
    'mac-euro2'                => '"Euro and cent"',
    'mac-fi-latin1'            => '"Finnish QWERTY keymap for Macintosh"',
    'mac-fr'                   => '"French AZERTY Macintosh keyboard"',
    'mac-fr_CH-latin1'         => '"Swiss-French QWERTY keymap for PowerBook G3 (Bronze Series)"',
    'mac-it'                   => '"Apple AZERTY Keyboard Italiana"',
    'mac-pl'                   => '"Apple QWERTZ Polish keymap"',
    'mac-pt-latin1'            => '"Apple QWERTY Portuguese keymap"',
    'mac-se'                   => '"Apple QWERTY Swedish keymap"',
    'mac-template'             => '"Apple QWERTY US keymap"',
    'mac-uk'                   => '"Apple QWERTY UK keymap"',
    'mac-us'                   => '"Apple QWERTY US keymap"',
    'mk'                       => '"Macedonian QWERTY keymap"',
    'mk-cp1251'                => '"Macedonian QWERTY keymap (cp-1251 version)"',
    'mk-utf'                   => '"Macedonian QWERTY keymap (UTF-8 version)"',
    'mk0'                      => '"Macedonian Cyrilic QWERTY Unicode keymap"',
    'nl'                       => '"Dutch QWERTY keymap for IBM ThinkPads (765L, 600, 770 and 380)"',
    'nl2'                      => '"Dutch QWERTY keymap for Windows-compatible 104 key keyboards"',
    'no'                       => '"Norwegian QWERTY keymap"',
    'no-dvorak'                => '"Norwegian Dvorak keymap"',
    'no-latin1'                => '"Norwegian QWERTY keymap"',
    'pc110'                    => '"Japanese/English keyboard on IBM PC110 Palm Top"',
    'pl'                       => '"Polish QWERTY programmers keyboard + paragraph sign AltGr-4"',
    'pl1'                      => '"Polish QWERTY programmers keyboard + paragraph sign AltGr-4"',
    'pl2'                      => '"Polish QWERTY programmers keyboard + paragraph sign AltGr-4"',
    'pl3'                      => '"Polish QWERTY programmers keyboard + paragraph sign AltGr-4"',
    'pl4'                      => '"Polish QWERTY programmers keyboard"',
    'pt-latin1'                => '"Portuguese QWERTY keymap"',
    'pt-latin9'                => '"Portuguese QWERTY keymap"',
    'pt-olpc'                  => '"Portuguese QWERTY keymap for OLPC"',
    'ro'                       => '"Romanian keymap, programmers style with AltGr as modifier"',
    'ro_std'                   => '"Standard Romanian layout as of SR13992:2004"',
    'ro_win'                   => '"A new Romanian keymap"',
    'ru'                       => '"Russian UTF-8 keymap for a 102 key keyboard"',
    'ru-cp1251'                => '"Russian CP1251 Cyrillic keymap"',
    'ru-ms'                    => '"Russian UTF-8 keymap for a 102 key keyboard optimized for Emacs"',
    'ru-yawerty'               => '"Cyrillic Yawerty keymap"',
    'ru1'                      => '"Russian UTF-8 keymap for a 102 key keyboard optimized for Emacs"',
    'ru2'                      => '"Russian alternative Cyrillic keymap, similar to Russian MS-DOS"',
    'ru3'                      => '"Russian UTF-8 keymap for a 102 key keyboard"',
    'ru4'                      => '"Russian UTF-8 keymap for a 102 key keyboard"',
    'ru_win'                   => '"Russian cp1251 (Windows Cyrillic) keymap"',
    'ruwin_alt-CP1251'         => '"Russian keymap for MS (105 key) keyboard, conformant to win-layout"',
    'ruwin_alt-KOI8-R'         => '"Russian keymap for MS (105 key) keyboard, conformant to win-layout"',
    'ruwin_alt-UTF-8'          => '"Russian keymap for MS (105 key) keyboard, conformant to win-layout"',
    'ruwin_alt_sh-UTF-8'       => '"Russian keymap for MS (105 key) keyboard, Alt-Shift toggles Russian/Latin"',
    'ruwin_cplk-CP1251'        => '"Russian keymap for MS (105 key) keyboard, conformant to win-layout"',
    'ruwin_cplk-KOI8-R'        => '"Russian keymap for MS (105 key) keyboard, conformant to win-layout"',
    'ruwin_cplk-UTF-8'         => '"Russian keymap for MS (105 key) keyboard, conformant to win-layout"',
    'ruwin_ct_sh-CP1251'       => '"Russian keymap for MS (105 key) keyboard, left/right insensitive"',
    'ruwin_ct_sh-KOI8-R'       => '"Russian keymap for MS (105 key) keyboard, left/right insensitive"',
    'ruwin_ct_sh-UTF-8'        => '"Russian keymap for MS (105 key) keyboard, left/right insensitive"',
    'ruwin_ctrl-CP1251'        => '"Russian keymap for MS (105 key) keyboard, RightCtrl toggles Russian/Latin"',
    'ruwin_ctrl-KOI8-R'        => '"Russian keymap for MS (105 key) keyboard, RightCtrl toggles Russian/Latin"',
    'ruwin_ctrl-UTF-8'         => '"Russian keymap for MS (105 key) keyboard, RightCtrl toggles Russian/Latin"',
    'se-fi-ir209'              => '"QWERTY keymap for use in Finland and Sweden"',
    'se-fi-lat6'               => '"QWERTY keymap for use in Finland and Sweden"',
    'se-ir209'                 => '"QWERTY keymap for use in Finland and Sweden"',
    'se-lat6'                  => '"QWERTY keymap for use in Finland and Sweden"',
    'sg'                       => '"QWERTZ keymap for use in Singapore"',
    'sg-latin1'                => '"QWERTZ keymap for use in Singapore"',
    'sg-latin1-lk450'          => '"QWERTZ keymap for use in Singapore"',
    'sk-prog-qwerty'           => '"Slovak ISO 8859-2 QWERTY keymap for text console"',
    'sk-prog-qwertz'           => '"Slovak ISO 8859-2 QWERTZ keymap for text console"',
    'sk-qwerty'                => '"Slovak ISO 8859-2 QWERTY keymap for text console"',
    'sk-qwertz'                => '"Slovak ISO 8859-2 QWERTZ keymap for text console"',
    'slovene'                  => '"Slovene QWERTZ keymap"',
    'sr-cy'                    => '"Serbian QWERTY Cyrillic keymap"',
    'sun-pl'                   => '"Polish keymap for the Sun Type4/Type5 keyboards"',
    'sun-pl-altgraph'          => '"Polish keymap for the Sun Type4/Type5 keyboards found on SparcStations"',
    'sundvorak'                => '"Dvorak keymap for the Sun Type4/Type5 keyboards found on SparcStations"',
    'sunkeymap'                => '"Keymap for the Sun Type4/Type5 keyboards found on SparcStations"',
    'sunt4-es'                 => '"Sun Type 4 Catalan and Spanish keyboard mapping"',
    'sunt4-fi-latin1'          => '"Keymap for Finnish Sun type 4 keyboard"',
    'sunt4-no-latin1'          => '"Sun Type 4 Norwegian keyboard mapping"',
    'sunt5-cz-us'              => '"Czech keymap for the Sun Type4/Type5 keyboards found on SparcStations"',
    'sunt5-de-latin1'          => '"German SUN-type-5 keymap"',
    'sunt5-es'                 => '"Sun Type 5 Spanish keymap"',
    'sunt5-fi-latin1'          => '"Sun Type 5 Finnish keymap"',
    'sunt5-fr-latin1'          => '"French keymap for the Sun Type4/Type5 keyboards found on SparcStations"',
    'sunt5-ru'                 => '"Russian keyboard layout for Type4/5 Sun keyboards"',
    'sunt5-uk'                 => '"UK keyboard layout for Type4/5 Sun keyboards"',
    'sunt5-us-cz'              => '"Czech keymap for the Sun Type4/Type5 keyboards found on SparcStations"',
    'sunt6-uk'                 => '"UK keyboard map for the Sun Type-6 keyboard with Euro and Latin 1/2 compose sequences support"',
    'sv-latin1'                => '"Swedish QWERTY keymap"',
    'tj_alt-UTF8'              => '"Tajik standard keyboard layout for 105 key PC keyboards"',
    'tr_f-latin5'              => '"Turkish F keyboard, copyed from LyX turkish keyboard description"',
    'tr_q-latin5'              => '"Turkish Q keyboard, copyed from LyX turkish keyboard description"',
    'tralt'                    => '"Turkish QWERTY keymap"',
    'trf'                      => '"Turkish QWERTY ISO-8859-9 F-Keyboard Map (105 key)"',
    'trf-fgGIod'               => '"Turkish ISO-8859-9 keymap"',
    'trq'                      => '"Turkish QWERTY ISO-8859-9 Q-Keyboard Map (105 key)"',
    'ttwin_alt-UTF-8'          => '"Tatarian QWERTY keymap"',
    'ttwin_cplk-UTF-8'         => '"Tatarian QWERTY keymap"',
    'ttwin_ct_sh-UTF-8'        => '"Tatarian QWERTY keymap"',
    'ttwin_ctrl-UTF-8'         => '"Tatarian QWERTY keymap"',
    'ua'                       => '"Ukrainian QWERTY Cyrillic keyboard"',
    'ua-cp1251'                => '"Ukrainian QWERTY CP1251 Cyrillic keyboard"',
    'ua-utf'                   => '"Ukrainian QWERTY Cyrillic keyboard"',
    'ua-utf-ws'                => '"Ukrainian QWERTY Cyrillic keyboard"',
    'ua-ws'                    => '"Ukrainian QWERTY Cyrillic keyboard"',
    'uk'                       => '"UK QWERTY keymap"',
    'unicode'                  => '"Unicode keymap"',
    'us'                       => '"US QWERTY keymap"',
    'us-acentos'               => '"Equivalente ao mapa us, incluindo dead_keys e composies dos caracteres acentuados"',
    'us-capslock-backspace'    => '"US QWERTY keymap with capslock remapped to backspace"',
    'wangbe'                   => '"AZERTY keymap for Wang Belgium keyboards"',
    'wangbe2'                  => '"AZERTY keymap for Wang Belgium keyboards"',
    'windowkeys'               => '"Extra 105 Windows keys"'
);

# end keymaps }}}
# locales {{{

constant %locales = Map.new(
    'POSIX'                 => '"POSIX Standard Locale"',
    'aa_DJ'                 => '"Afar language locale for Djibouti (Cadu/Laaqo Dialects)"',
    'aa_ER'                 => '"Afar language locale for Eritrea (Cadu/Laaqo Dialects)"',
    'aa_ER@saaho'           => '"Afar language locale for Eritrea (Saaho Dialect)"',
    'aa_ET'                 => '"Afar language locale for Ethiopia (Cadu/Carra Dialects)"',
    'af_ZA'                 => '"Afrikaans locale for South Africa"',
    'agr_PE'                => '"Awajún / Aguaruna (agr) language locale for Peru"',
    'ak_GH'                 => '"Akan locale for Ghana"',
    'am_ET'                 => '"Amharic language locale for Ethiopia"',
    'an_ES'                 => '"Aragonese locale for Spain"',
    'anp_IN'                => '"Angika language locale for India"',
    'ar_AE'                 => '"Arabic language locale for United Arab Emirates"',
    'ar_BH'                 => '"Arabic language locale for Bahrain"',
    'ar_DZ'                 => '"Arabic language locale for Algeria"',
    'ar_EG'                 => '"Arabic language locale for Egypt"',
    'ar_IN'                 => '"Arabic language locale for India"',
    'ar_IQ'                 => '"Arabic language locale for Iraq"',
    'ar_JO'                 => '"Arabic language locale for Jordan"',
    'ar_KW'                 => '"Arabic language locale for Kuwait"',
    'ar_LB'                 => '"Arabic language locale for Lebanon"',
    'ar_LY'                 => '"Arabic language locale for Libyan Arab Jamahiriya"',
    'ar_MA'                 => '"Arabic language locale for Morocco"',
    'ar_OM'                 => '"Arabic language locale for Oman"',
    'ar_QA'                 => '"Arabic language locale for Qatar"',
    'ar_SA'                 => '"Arabic language locale for Saudi Arabia"',
    'ar_SD'                 => '"Arabic language locale for Sudan"',
    'ar_SS'                 => '"Arabic language locale for South Sudan"',
    'ar_SY'                 => '"Arabic language locale for Syrian Arab Republic"',
    'ar_TN'                 => '"Arabic language locale for Tunisia"',
    'ar_YE'                 => '"Arabic language locale for Yemen"',
    'as_IN'                 => '"Assamese language locale for India"',
    'ast_ES'                => '"Asturian locale for Spain"',
    'ayc_PE'                => '"Aymara (ayc) locale for Peru"',
    'az_AZ'                 => '"Azeri language locale for Azerbaijan (latin)"',
    'az_IR'                 => '"South Azerbaijani Language Locale for Iran"',
    'be_BY'                 => '"Belarusian locale for Belarus"',
    'be_BY@latin'           => '"Belarusian Latin-Script locale for Belarus"',
    'bem_ZM'                => '"Bemba locale for Zambia"',
    'ber_DZ'                => '"Amazigh language locale for Algeria (latin)"',
    'ber_MA'                => '"Amazigh language locale for Morocco (tifinagh)"',
    'bg_BG'                 => '"Bulgarian locale for Bulgaria"',
    'bhb_IN'                => '"Bhili(devanagari) language locale for India"',
    'bho_IN'                => '"Bhojpuri language locale for India"',
    'bho_NP'                => '"Bhojpuri language locale for Nepal"',
    'bi_VU'                 => '"Bislama language locale for Vanuatu"',
    'bn_BD'                 => '"Bengali/Bangla language locale for Bangladesh"',
    'bn_IN'                 => '"Bengali language locale for India"',
    'bo_CN'                 => '"Tibetan language locale for P.R. of China"',
    'bo_IN'                 => '"Tibetan language locale for India"',
    'br_FR'                 => '"Breton language locale for France"',
    'br_FR@euro'            => '"Breton locale for France with Euro"',
    'brx_IN'                => '"Bodo language locale for India"',
    'bs_BA'                 => '"Bosnian language locale for Bosnia and Herzegowina"',
    'byn_ER'                => '"Blin language locale for Eritrea"',
    'ca_AD'                 => '"Catalan locale for Andorra"',
    'ca_ES'                 => '"Catalan locale for Spain"',
    'ca_ES@euro'            => '"Catalan locale for Catalonia with Euro"',
    'ca_ES@valencia'        => '"Valencian (southern Catalan) locale for Spain with Euro"',
    'ca_FR'                 => '"Catalan locale for France"',
    'ca_IT'                 => '"Catalan locale for Italy (L\'Alguer)"',
    'ce_RU'                 => '"Chechen locale for Russian Federation"',
    'chr_US'                => '"Cherokee language locale for United States"',
    'cmn_TW'                => '"Mandarin Chinese locale for the Republic of China"',
    'cns11643_stroke'       => '"Collation for Hanzi(chinese characters) by component and stroke"',
    'crh_UA'                => '"Crimean Tatar (Crimean Turkish) language locale for Ukraine"',
    'cs_CZ'                 => '"Czech locale for the Czech Republic"',
    'csb_PL'                => '"Kashubian locale for Poland"',
    'cv_RU'                 => '"Chuvash locale for Russia"',
    'cy_GB'                 => '"Welsh language locale for Great Britain"',
    'da_DK'                 => '"Danish locale for Denmark"',
    'de_AT'                 => '"German locale for Austria"',
    'de_AT@euro'            => '"German locale for Austria with Euro"',
    'de_BE'                 => '"German locale for Belgium"',
    'de_BE@euro'            => '"German locale for Belgium with Euro"',
    'de_CH'                 => '"German locale for Switzerland"',
    'de_DE'                 => '"German locale for Germany"',
    'de_DE@euro'            => '"German locale for Germany with Euro"',
    'de_IT'                 => '"German Language Locale for Italy"',
    'de_LI'                 => '"German locale for Liechtenstein"',
    'de_LU'                 => '"German locale for Luxemburg"',
    'de_LU@euro'            => '"German locale for Luxemburg with Euro"',
    'doi_IN'                => '"Dogri language locale for India"',
    'dsb_DE'                => '"Lower Sorbian Language Locale for Germany"',
    'dv_MV'                 => '"Dhivehi language locale for Maldives"',
    'dz_BT'                 => '"Dzongkha language locale for Bhutan"',
    'el_CY'                 => '"Greek locale for Cyprus"',
    'el_GR'                 => '"Greek locale for Greece"',
    'el_GR@euro'            => '"Greek locale for Greece with Euro"',
    'en_AG'                 => '"English language locale for Antigua and Barbuda"',
    'en_AU'                 => '"English locale for Australia"',
    'en_BW'                 => '"English locale for Botswana"',
    'en_CA'                 => '"English locale for Canada"',
    'en_DK'                 => '"English language locale for Denmark"',
    'en_GB'                 => '"English language locale for Britain"',
    'en_HK'                 => '"English locale for Hong Kong"',
    'en_IE'                 => '"English language locale for Ireland"',
    'en_IE@euro'            => '"English language locale for Ireland with Euro"',
    'en_IL'                 => '"English locale for Israel"',
    'en_IN'                 => '"English language locale for India"',
    'en_NG'                 => '"English locale for Nigeria"',
    'en_NZ'                 => '"English locale for New Zealand"',
    'en_PH'                 => '"English language locale for Philippines"',
    'en_SC'                 => '"English locale for the Seychelles"',
    'en_SG'                 => '"English language locale for Singapore"',
    'en_US'                 => '"English locale for the USA"',
    'en_ZA'                 => '"English locale for South Africa"',
    'en_ZM'                 => '"English locale for Zambia"',
    'en_ZW'                 => '"English locale for Zimbabwe"',
    'eo'                    => '"Esperanto Language Locale"',
    'es_AR'                 => '"Spanish locale for Argentina"',
    'es_BO'                 => '"Spanish locale for Bolivia"',
    'es_CL'                 => '"Spanish locale for Chile"',
    'es_CO'                 => '"Spanish locale for Colombia"',
    'es_CR'                 => '"Spanish locale for Costa Rica"',
    'es_CU'                 => '"Spanish locale for Cuba"',
    'es_DO'                 => '"Spanish locale for Dominican Republic"',
    'es_EC'                 => '"Spanish locale for Ecuador"',
    'es_ES'                 => '"Spanish locale for Spain"',
    'es_ES@euro'            => '"Spanish locale for Spain with Euro"',
    'es_GT'                 => '"Spanish locale for Guatemala"',
    'es_HN'                 => '"Spanish locale for Honduras"',
    'es_MX'                 => '"Spanish locale for Mexico"',
    'es_NI'                 => '"Spanish locale for Nicaragua"',
    'es_PA'                 => '"Spanish locale for Panama"',
    'es_PE'                 => '"Spanish locale for Peru"',
    'es_PR'                 => '"Spanish locale for Puerto Rico"',
    'es_PY'                 => '"Spanish locale for Paraguay"',
    'es_SV'                 => '"Spanish locale for El Salvador"',
    'es_US'                 => '"Spanish locale for the USA"',
    'es_UY'                 => '"Spanish locale for Uruguay"',
    'es_VE'                 => '"Spanish locale for Venezuela"',
    'et_EE'                 => '"Estonian locale for Estonia"',
    'eu_ES'                 => '"Basque locale for Spain"',
    'eu_ES@euro'            => '"Basque language locale for Spain with Euro"',
    'fa_IR'                 => '"Persian locale for Iran"',
    'ff_SN'                 => '"Fulah locale for Senegal"',
    'fi_FI'                 => '"Finnish locale for Finland"',
    'fi_FI@euro'            => '"Finnish locale for Finland with Euro"',
    'fil_PH'                => '"Filipino language locale for Philippines"',
    'fo_FO'                 => '"Faroese locale for Faroe Islands"',
    'fr_BE'                 => '"French locale for Belgium"',
    'fr_BE@euro'            => '"French locale for Belgium with Euro"',
    'fr_CA'                 => '"French locale for Canada"',
    'fr_CH'                 => '"French locale for Switzerland"',
    'fr_FR'                 => '"French locale for France"',
    'fr_FR@euro'            => '"French locale for France with Euro"',
    'fr_LU'                 => '"French locale for Luxemburg"',
    'fr_LU@euro'            => '"French locale for Luxemburg with Euro"',
    'fur_IT'                => '"Furlan locale for Italy"',
    'fy_DE'                 => '"Sater Frisian and North Frisian locale for Germany"',
    'fy_NL'                 => '"Frisian locale for the Netherlands"',
    'ga_IE'                 => '"Irish locale for Ireland"',
    'ga_IE@euro'            => '"Irish locale for Ireland with Euro"',
    'gd_GB'                 => '"Scots Gaelic language locale for Great Britain"',
    'gez_ER'                => '"Ge\'ez language locale for Eritrea"',
    'gez_ER@abegede'        => '"Ge\'ez language locale for Eritrea With Abegede Collation."',
    'gez_ET'                => '"Ge\'ez language locale for Ethiopia"',
    'gez_ET@abegede'        => '"Ge\'ez language locale for Ethiopia With Abegede Collation"',
    'gl_ES'                 => '"Galician locale for Spain"',
    'gl_ES@euro'            => '"Galician locale for Spain with Euro"',
    'gu_IN'                 => '"Gujarati language locale For India"',
    'gv_GB'                 => '"Manx Gaelic locale for Britain"',
    'ha_NG'                 => '"Hausa locale for Nigeria"',
    'hak_TW'                => '"Hakka Chinese locale for the Republic of China"',
    'he_IL'                 => '"Hebrew locale for Israel"',
    'hi_IN'                 => '"Hindi language locale for India"',
    'hif_FJ'                => '"Fiji Hindi language locale same as Hindi for Fiji"',
    'hne_IN'                => '"Chhattisgarhi language locale for India"',
    'hr_HR'                 => '"Croatian locale for Croatia"',
    'hsb_DE'                => '"Upper Sorbian locale for Germany"',
    'ht_HT'                 => '"Kreyol locale for Haiti"',
    'hu_HU'                 => '"Hungarian locale for Hungary"',
    'hy_AM'                 => '"Armenian language locale for Armenia"',
    'i18n'                  => '"ISO/IEC 14652 i18n definitions"',
    'i18n_ctype'            => '"Unicode 10.0.0 FDCC-set"',
    'ia_FR'                 => '"Interlingua locale for France"',
    'id_ID'                 => '"Indonesian locale for Indonesia"',
    'ig_NG'                 => '"Igbo locale for Nigeria"',
    'ik_CA'                 => '"Inupiaq locale for Canada"',
    'is_IS'                 => '"Icelandic locale for Iceland"',
    'iso14651_t1'           => '"International string ordering and comparison"',
    'iso14651_t1_common'    => '"International string ordering and comparison"',
    'iso14651_t1_pinyin'    => '"International string ordering and comparison"',
    'it_CH'                 => '"Italian locale for Switzerland"',
    'it_IT'                 => '"Italian locale for Italy"',
    'it_IT@euro'            => '"Italian locale for Italy with Euro"',
    'iu_CA'                 => '"Inuktitut language locale for Nunavut, Canada"',
    'iw_IL'                 => '"Hebrew locale for Israel"',
    'ja_JP'                 => '"Japanese language locale for Japan"',
    'ka_GE'                 => '"Georgian language locale for Georgia"',
    'kab_DZ'                => '"Kabyle language locale for Algeria"',
    'kk_KZ'                 => '"Kazakh locale for Kazakhstan"',
    'kl_GL'                 => '"Greenlandic locale for Greenland"',
    'km_KH'                 => '"Khmer locale for Cambodia"',
    'kn_IN'                 => '"Kannada language locale for India"',
    'ko_KR'                 => '"Korean locale for Republic of Korea"',
    'kok_IN'                => '"Konkani language locale for India"',
    'ks_IN'                 => '"Kashmiri language locale for India"',
    'ks_IN@devanagari'      => '"Kashmiri(devanagari) language locale for India"',
    'ku_TR'                 => '"Kurdish (latin) locale for Turkey"',
    'kw_GB'                 => '"Cornish locale for Britain"',
    'ky_KG'                 => '"Kyrgyz language locale for Kyrgyzstan"',
    'lb_LU'                 => '"Luxembourgish locale for Luxembourg"',
    'lg_UG'                 => '"Luganda locale for Uganda"',
    'li_BE'                 => '"Limburgish language locale for Belgium"',
    'li_NL'                 => '"Limburgish language locale for the Netherlands"',
    'lij_IT'                => '"Ligurian locale for Italy"',
    'ln_CD'                 => '"Lingala locale for Democratic Republic of the Congo"',
    'lo_LA'                 => '"Lao locale for Laos"',
    'lt_LT'                 => '"Lithuanian locale for Lithuania"',
    'lv_LV'                 => '"Latvian locale for Latvia"',
    'lzh_TW'                => '"Literary Chinese locale for the Republic of China"',
    'mag_IN'                => '"Magahi language locale for India"',
    'mai_IN'                => '"Maithili language locale for India"',
    'mai_NP'                => '"Maithili language locale for Nepal"',
    'mfe_MU'                => '"Morisyen locale for Mauritius"',
    'mg_MG'                 => '"Malagasy locale for Madagascar"',
    'mhr_RU'                => '"Mari locale for Russia"',
    'mi_NZ'                 => '"Maori language locale for New Zealand"',
    'miq_NI'                => '"Miskito language locale for Nicaragua"',
    'mjw_IN'                => '"Karbi language locale for India"',
    'mk_MK'                 => '"Macedonian locale for Macedonia"',
    'ml_IN'                 => '"Malayalam language locale for India"',
    'mn_MN'                 => '"Mongolian locale for Mongolia"',
    'mni_IN'                => '"Manipuri language locale for India"',
    'mr_IN'                 => '"Marathi language locale for India"',
    'ms_MY'                 => '"Malay language locale for Malaysia"',
    'mt_MT'                 => '"Maltese language locale for Malta"',
    'my_MM'                 => '"Burmese language locale for Myanmar"',
    'nan_TW'                => '"Min Nan Chinese locale for the Republic of China"',
    'nan_TW@latin'          => '"Minnan language locale for Taiwan"',
    'nb_NO'                 => '"Norwegian (Bokmal) locale for Norway"',
    'nds_DE'                => '"Low(lands) Saxon language locale for Germany"',
    'nds_NL'                => '"Low(lands) Saxon language locale for the Netherlands"',
    'ne_NP'                 => '"Nepali language locale for Nepal"',
    'nhn_MX'                => '"Central Nahuatl for Mexico"',
    'niu_NU'                => '"Niuean (Vagahau Niue) locale for Niue"',
    'niu_NZ'                => '"Niuean (Vagahau Niue) locale for New Zealand"',
    'nl_AW'                 => '"Dutch language locale for Aruba"',
    'nl_BE'                 => '"Dutch locale for Belgium"',
    'nl_BE@euro'            => '"Dutch locale for Belgium with Euro"',
    'nl_NL'                 => '"Dutch locale for the Netherlands"',
    'nl_NL@euro'            => '"Dutch locale for the Netherlands with Euro"',
    'nn_NO'                 => '"Nynorsk language locale for Norway"',
    'nr_ZA'                 => '"Southern Ndebele locale for South Africa"',
    'nso_ZA'                => '"Northern Sotho locale for South Africa"',
    'oc_FR'                 => '"Occitan language locale for France"',
    'om_ET'                 => '"Oromo language locale for Ethiopia"',
    'om_KE'                 => '"Oromo language locale for Kenya"',
    'or_IN'                 => '"Odia language locale for India"',
    'os_RU'                 => '"Ossetian locale for Russia"',
    'pa_IN'                 => '"Punjabi language locale for Indian Punjabi(Gurmukhi)"',
    'pa_PK'                 => '"Punjabi (Shahmukhi) language locale for Pakistan"',
    'pap_AN'                => '"Papiamento language for the (Netherland) Antilles"',
    'pap_AW'                => '"Papiamento language for Aruba"',
    'pap_CW'                => '"Papiamento language for Curaçao"',
    'pl_PL'                 => '"Polish locale for Poland"',
    'ps_AF'                 => '"Pashto locale for Afghanistan"',
    'pt_BR'                 => '"Portuguese locale for Brasil"',
    'pt_PT'                 => '"Portuguese locale for Portugal"',
    'pt_PT@euro'            => '"Portuguese locale for Portugal with Euro"',
    'quz_PE'                => '"Quechua (Cusco-Collao) locale for Peru"',
    'raj_IN'                => '"Rajasthani language locale for India"',
    'ro_RO'                 => '"Romanian locale for Romania"',
    'ru_RU'                 => '"Russian locale for Russia"',
    'ru_UA'                 => '"Russian locale for Ukraine"',
    'rw_RW'                 => '"Kinyarwanda language locale for Rwanda"',
    'sa_IN'                 => '"Sanskrit language locale for India"',
    'sah_RU'                => '"Yakut (Sakha) locale for Russian Federation"',
    'sat_IN'                => '"Santali language locale for India"',
    'sc_IT'                 => '"Sardinian locale for Italy"',
    'sd_IN'                 => '"Sindhi language locale for India"',
    'sd_IN@devanagari'      => '"Sindhi language locale for India"',
    'se_NO'                 => '"Northern Saami language locale for Norway"',
    'sgs_LT'                => '"Samogitian language locale for Lithuania"',
    'shn_MM'                => '"Shan language locale for Myanmar"',
    'shs_CA'                => '"Secwepemctsin locale for Canada"',
    'si_LK'                 => '"Sinhala language locale for Sri Lanka"',
    'sid_ET'                => '"Sidama language locale for Ethiopia"',
    'sk_SK'                 => '"Slovak locale for Slovak"',
    'sl_SI'                 => '"Slovenian locale for Slovenia"',
    'sm_WS'                 => '"Samoan language locale for Samoa"',
    'so_DJ'                 => '"Somali language locale for Djibouti"',
    'so_ET'                 => '"Somali language locale for Ethiopia"',
    'so_KE'                 => '"Somali language locale for Kenya"',
    'so_SO'                 => '"Somali language locale for Somalia"',
    'sq_AL'                 => '"Albanian language locale for Albania"',
    'sq_MK'                 => '"Albanian language locale for Macedonia"',
    'sr_ME'                 => '"Serbian locale for Montenegro"',
    'sr_RS'                 => '"Serbian locale for Serbia"',
    'sr_RS@latin'           => '"Serbian Latin locale for Serbia"',
    'ss_ZA'                 => '"Swati locale for South Africa"',
    'st_ZA'                 => '"Sotho locale for South Africa"',
    'sv_FI'                 => '"Swedish locale for Finland"',
    'sv_FI@euro'            => '"Swedish locale for Finland with Euro"',
    'sv_SE'                 => '"Swedish locale for Sweden"',
    'sw_KE'                 => '"Swahili locale for Kenya"',
    'sw_TZ'                 => '"Swahili locale for Tanzania"',
    'szl_PL'                => '"Silesian locale for Poland"',
    'ta_IN'                 => '"Tamil language locale for India"',
    'ta_LK'                 => '"Tamil language locale for Sri Lanka"',
    'tcy_IN'                => '"Tulu language locale for India"',
    'te_IN'                 => '"Telugu language locale for India"',
    'tg_TJ'                 => '"Tajik language locale for Tajikistan"',
    'th_TH'                 => '"Thai locale for Thailand"',
    'the_NP'                => '"Tharu language locale for Nepal"',
    'ti_ER'                 => '"Tigrigna language locale for Eritrea"',
    'ti_ET'                 => '"Tigrigna language locale for Ethiopia"',
    'tig_ER'                => '"Tigre language locale for Eritrea"',
    'tk_TM'                 => '"Turkmen locale for Turkmenistan"',
    'tl_PH'                 => '"Tagalog language locale for Philippines"',
    'tn_ZA'                 => '"Tswana locale for South Africa"',
    'to_TO'                 => '"Tongan language locale for Tonga"',
    'tpi_PG'                => '"Tok Pisin language locale for Papua New Guinea"',
    'tr_CY'                 => '"Turkish language locale for Cyprus"',
    'tr_TR'                 => '"Turkish locale for Turkey"',
    'translit_circle'       => '"Transliterations of encircled characters"',
    'translit_cjk_compat'   => '"Transliterations of CJK compatibility characters"',
    'translit_cjk_variants' => '"Transliterations of CJK characters"',
    'translit_combining'    => '"Transliterations that remove all combining characters"',
    'translit_compat'       => '"Transliterations of compatibility characters and ligatures"',
    'translit_font'         => '"Transliterations of font equivalents"',
    'translit_fraction'     => '"Transliterations of fractions"',
    'translit_hangul'       => '"Transliterations of Hangul syllables to Jamo"',
    'translit_narrow'       => '"Transliterations of narrow equivalents"',
    'translit_neutral'      => '"Language and locale neutral transliterations"',
    'translit_small'        => '"Transliterations of small equivalents"',
    'translit_wide'         => '"Transliterations of wide equivalents"',
    'ts_ZA'                 => '"Tsonga locale for South Africa"',
    'tt_RU'                 => '"Tatar language locale for Russia"',
    'tt_RU@iqtelif'         => '"Tatar language locale using IQTElif alphabet for Tatarstan, Russian Federation"',
    'ug_CN'                 => '"Uyghur locale for China"',
    'uk_UA'                 => '"Ukrainian language locale for Ukraine"',
    'unm_US'                => '"Unami Delaware locale for the USA"',
    'ur_IN'                 => '"Urdu language locale for India"',
    'ur_PK'                 => '"Urdu language locale for Pakistan"',
    'uz_UZ'                 => '"Uzbek (latin) locale for Uzbekistan"',
    'uz_UZ@cyrillic'        => '"Uzbek (cyrillic) locale for Uzbekistan"',
    've_ZA'                 => '"Venda locale for South Africa"',
    'vi_VN'                 => '"Vietnamese language locale for Vietnam"',
    'wa_BE'                 => '"Walloon language locale for Belgium"',
    'wa_BE@euro'            => '"Walloon locale for Belgium with Euro"',
    'wae_CH'                => '"Walser locale for Switzerland"',
    'wal_ET'                => '"Walaita language locale for Ethiopia"',
    'wo_SN'                 => '"Wolof locale for Senegal"',
    'xh_ZA'                 => '"Xhosa locale for South Africa"',
    'yi_US'                 => '"Yiddish language locale for the USA"',
    'yo_NG'                 => '"Yoruba locale for Nigeria"',
    'yue_HK'                => '"Yue Chinese (Cantonese) language locale for Hong Kong"',
    'yuw_PG'                => '"Yau/Nungon locale for Papua New Guinea"',
    'zh_CN'                 => '"Chinese language locale for Peoples Republic of China"',
    'zh_HK'                 => '"Chinese language locale for Hong Kong"',
    'zh_SG'                 => '"Chinese language locale for Singapore"',
    'zh_TW'                 => '"Chinese language locale for Taiwan R.O.C."',
    'zu_ZA'                 => '"Zulu locale for South Africa"'
);

# end locales }}}
# processors {{{

constant %processors = Map.new(
    'INTEL' => '"Intel processors"',
    'OTHER' => '"All other processors"'
);

# end processors }}}
# timezones {{{

constant @timezones = qw<
    Africa/Abidjan
    Africa/Accra
    Africa/Addis_Ababa
    Africa/Algiers
    Africa/Asmara
    Africa/Bamako
    Africa/Bangui
    Africa/Banjul
    Africa/Bissau
    Africa/Blantyre
    Africa/Brazzaville
    Africa/Bujumbura
    Africa/Cairo
    Africa/Casablanca
    Africa/Ceuta
    Africa/Conakry
    Africa/Dakar
    Africa/Dar_es_Salaam
    Africa/Djibouti
    Africa/Douala
    Africa/El_Aaiun
    Africa/Freetown
    Africa/Gaborone
    Africa/Harare
    Africa/Johannesburg
    Africa/Juba
    Africa/Kampala
    Africa/Khartoum
    Africa/Kigali
    Africa/Kinshasa
    Africa/Lagos
    Africa/Libreville
    Africa/Lome
    Africa/Luanda
    Africa/Lubumbashi
    Africa/Lusaka
    Africa/Malabo
    Africa/Maputo
    Africa/Maseru
    Africa/Mbabane
    Africa/Mogadishu
    Africa/Monrovia
    Africa/Nairobi
    Africa/Ndjamena
    Africa/Niamey
    Africa/Nouakchott
    Africa/Ouagadougou
    Africa/Porto-Novo
    Africa/Sao_Tome
    Africa/Tripoli
    Africa/Tunis
    Africa/Windhoek
    America/Adak
    America/Anchorage
    America/Anguilla
    America/Antigua
    America/Araguaina
    America/Argentina/Buenos_Aires
    America/Argentina/Catamarca
    America/Argentina/Cordoba
    America/Argentina/Jujuy
    America/Argentina/La_Rioja
    America/Argentina/Mendoza
    America/Argentina/Rio_Gallegos
    America/Argentina/Salta
    America/Argentina/San_Juan
    America/Argentina/San_Luis
    America/Argentina/Tucuman
    America/Argentina/Ushuaia
    America/Aruba
    America/Asuncion
    America/Atikokan
    America/Bahia
    America/Bahia_Banderas
    America/Barbados
    America/Belem
    America/Belize
    America/Blanc-Sablon
    America/Boa_Vista
    America/Bogota
    America/Boise
    America/Cambridge_Bay
    America/Campo_Grande
    America/Cancun
    America/Caracas
    America/Cayenne
    America/Cayman
    America/Chicago
    America/Chihuahua
    America/Costa_Rica
    America/Creston
    America/Cuiaba
    America/Curacao
    America/Danmarkshavn
    America/Dawson
    America/Dawson_Creek
    America/Denver
    America/Detroit
    America/Dominica
    America/Edmonton
    America/Eirunepe
    America/El_Salvador
    America/Fort_Nelson
    America/Fortaleza
    America/Glace_Bay
    America/Godthab
    America/Goose_Bay
    America/Grand_Turk
    America/Grenada
    America/Guadeloupe
    America/Guatemala
    America/Guayaquil
    America/Guyana
    America/Halifax
    America/Havana
    America/Hermosillo
    America/Indiana/Indianapolis
    America/Indiana/Knox
    America/Indiana/Marengo
    America/Indiana/Petersburg
    America/Indiana/Tell_City
    America/Indiana/Vevay
    America/Indiana/Vincennes
    America/Indiana/Winamac
    America/Inuvik
    America/Iqaluit
    America/Jamaica
    America/Juneau
    America/Kentucky/Louisville
    America/Kentucky/Monticello
    America/Kralendijk
    America/La_Paz
    America/Lima
    America/Los_Angeles
    America/Lower_Princes
    America/Maceio
    America/Managua
    America/Manaus
    America/Marigot
    America/Martinique
    America/Matamoros
    America/Mazatlan
    America/Menominee
    America/Merida
    America/Metlakatla
    America/Mexico_City
    America/Miquelon
    America/Moncton
    America/Monterrey
    America/Montevideo
    America/Montserrat
    America/Nassau
    America/New_York
    America/Nipigon
    America/Nome
    America/Noronha
    America/North_Dakota/Beulah
    America/North_Dakota/Center
    America/North_Dakota/New_Salem
    America/Ojinaga
    America/Panama
    America/Pangnirtung
    America/Paramaribo
    America/Phoenix
    America/Port-au-Prince
    America/Port_of_Spain
    America/Porto_Velho
    America/Puerto_Rico
    America/Punta_Arenas
    America/Rainy_River
    America/Rankin_Inlet
    America/Recife
    America/Regina
    America/Resolute
    America/Rio_Branco
    America/Santa_Isabel
    America/Santarem
    America/Santiago
    America/Santo_Domingo
    America/Sao_Paulo
    America/Scoresbysund
    America/Sitka
    America/St_Barthelemy
    America/St_Johns
    America/St_Kitts
    America/St_Lucia
    America/St_Thomas
    America/St_Vincent
    America/Swift_Current
    America/Tegucigalpa
    America/Thule
    America/Thunder_Bay
    America/Tijuana
    America/Toronto
    America/Tortola
    America/Vancouver
    America/Whitehorse
    America/Winnipeg
    America/Yakutat
    America/Yellowknife
    Antarctica/Casey
    Antarctica/Davis
    Antarctica/DumontDUrville
    Antarctica/Macquarie
    Antarctica/Mawson
    Antarctica/McMurdo
    Antarctica/Palmer
    Antarctica/Rothera
    Antarctica/Syowa
    Antarctica/Troll
    Antarctica/Vostok
    Arctic/Longyearbyen
    Asia/Aden
    Asia/Almaty
    Asia/Amman
    Asia/Anadyr
    Asia/Aqtau
    Asia/Aqtobe
    Asia/Ashgabat
    Asia/Atyrau
    Asia/Baghdad
    Asia/Bahrain
    Asia/Baku
    Asia/Bangkok
    Asia/Barnaul
    Asia/Beirut
    Asia/Bishkek
    Asia/Brunei
    Asia/Chita
    Asia/Choibalsan
    Asia/Colombo
    Asia/Damascus
    Asia/Dhaka
    Asia/Dili
    Asia/Dubai
    Asia/Dushanbe
    Asia/Famagusta
    Asia/Gaza
    Asia/Hebron
    Asia/Ho_Chi_Minh
    Asia/Hong_Kong
    Asia/Hovd
    Asia/Irkutsk
    Asia/Jakarta
    Asia/Jayapura
    Asia/Jerusalem
    Asia/Kabul
    Asia/Kamchatka
    Asia/Karachi
    Asia/Kathmandu
    Asia/Khandyga
    Asia/Kolkata
    Asia/Krasnoyarsk
    Asia/Kuala_Lumpur
    Asia/Kuching
    Asia/Kuwait
    Asia/Macau
    Asia/Magadan
    Asia/Makassar
    Asia/Manila
    Asia/Muscat
    Asia/Nicosia
    Asia/Novokuznetsk
    Asia/Novosibirsk
    Asia/Omsk
    Asia/Oral
    Asia/Phnom_Penh
    Asia/Pontianak
    Asia/Pyongyang
    Asia/Qatar
    Asia/Qyzylorda
    Asia/Rangoon
    Asia/Riyadh
    Asia/Sakhalin
    Asia/Samarkand
    Asia/Seoul
    Asia/Shanghai
    Asia/Singapore
    Asia/Srednekolymsk
    Asia/Taipei
    Asia/Tashkent
    Asia/Tbilisi
    Asia/Tehran
    Asia/Thimphu
    Asia/Tokyo
    Asia/Tomsk
    Asia/Ulaanbaatar
    Asia/Urumqi
    Asia/Ust-Nera
    Asia/Vientiane
    Asia/Vladivostok
    Asia/Yakutsk
    Asia/Yangon
    Asia/Yekaterinburg
    Asia/Yerevan
    Atlantic/Azores
    Atlantic/Bermuda
    Atlantic/Canary
    Atlantic/Cape_Verde
    Atlantic/Faroe
    Atlantic/Madeira
    Atlantic/Reykjavik
    Atlantic/South_Georgia
    Atlantic/St_Helena
    Atlantic/Stanley
    Australia/Adelaide
    Australia/Brisbane
    Australia/Broken_Hill
    Australia/Currie
    Australia/Darwin
    Australia/Eucla
    Australia/Hobart
    Australia/Lindeman
    Australia/Lord_Howe
    Australia/Melbourne
    Australia/Perth
    Australia/Sydney
    Europe/Amsterdam
    Europe/Andorra
    Europe/Astrakhan
    Europe/Athens
    Europe/Belgrade
    Europe/Berlin
    Europe/Bratislava
    Europe/Brussels
    Europe/Bucharest
    Europe/Budapest
    Europe/Busingen
    Europe/Chisinau
    Europe/Copenhagen
    Europe/Dublin
    Europe/Gibraltar
    Europe/Guernsey
    Europe/Helsinki
    Europe/Isle_of_Man
    Europe/Istanbul
    Europe/Jersey
    Europe/Kaliningrad
    Europe/Kiev
    Europe/Kirov
    Europe/Lisbon
    Europe/Ljubljana
    Europe/London
    Europe/Luxembourg
    Europe/Madrid
    Europe/Malta
    Europe/Mariehamn
    Europe/Minsk
    Europe/Monaco
    Europe/Moscow
    Europe/Oslo
    Europe/Paris
    Europe/Podgorica
    Europe/Prague
    Europe/Riga
    Europe/Rome
    Europe/Samara
    Europe/San_Marino
    Europe/Sarajevo
    Europe/Saratov
    Europe/Simferopol
    Europe/Skopje
    Europe/Sofia
    Europe/Stockholm
    Europe/Tallinn
    Europe/Tirane
    Europe/Ulyanovsk
    Europe/Uzhgorod
    Europe/Vaduz
    Europe/Vatican
    Europe/Vienna
    Europe/Vilnius
    Europe/Volgograd
    Europe/Warsaw
    Europe/Zagreb
    Europe/Zaporozhye
    Europe/Zurich
    Indian/Antananarivo
    Indian/Chagos
    Indian/Christmas
    Indian/Cocos
    Indian/Comoro
    Indian/Kerguelen
    Indian/Mahe
    Indian/Maldives
    Indian/Mauritius
    Indian/Mayotte
    Indian/Reunion
    Pacific/Apia
    Pacific/Auckland
    Pacific/Bougainville
    Pacific/Chatham
    Pacific/Chuuk
    Pacific/Easter
    Pacific/Efate
    Pacific/Enderbury
    Pacific/Fakaofo
    Pacific/Fiji
    Pacific/Funafuti
    Pacific/Galapagos
    Pacific/Gambier
    Pacific/Guadalcanal
    Pacific/Guam
    Pacific/Honolulu
    Pacific/Johnston
    Pacific/Kiritimati
    Pacific/Kosrae
    Pacific/Kwajalein
    Pacific/Majuro
    Pacific/Marquesas
    Pacific/Midway
    Pacific/Nauru
    Pacific/Niue
    Pacific/Norfolk
    Pacific/Noumea
    Pacific/Pago_Pago
    Pacific/Palau
    Pacific/Pitcairn
    Pacific/Pohnpei
    Pacific/Port_Moresby
    Pacific/Rarotonga
    Pacific/Saipan
    Pacific/Tahiti
    Pacific/Tarawa
    Pacific/Tongatapu
    Pacific/Wake
    Pacific/Wallis
    UTC
>;

# end timezones }}}


# -----------------------------------------------------------------------------
# types
# -----------------------------------------------------------------------------

# hard disk type
subset DiskType of Str is export where { %disktypes.keys.grep($_) };

# graphics card type
subset Graphics of Str is export where { %graphics.keys.grep($_) };

# hostname (machine name)
subset HostName of Str is export where
{
    Archvault::Grammar.parse($_, :rule<host-name>);
}

# keymap
subset Keymap of Str is export where { %keymaps.keys.grep($_) };

# locale
subset Locale of Str is export where { %locales.keys.grep($_) };

# processor
subset Processor of Str is export where { %processors.keys.grep($_) };

# timezone
subset Timezone of Str is export where { @timezones.grep($_) };

# linux username
subset UserName of Str is export where
{
    Archvault::Grammar.parse($_, :rule<user-name>);
}

# LUKS encrypted volume device mapper name
subset VaultName of Str is export where
{
    Archvault::Grammar.parse($_, :rule<vault-name>);
}

# LUKS encrypted volume password must be 1-512 characters
subset VaultPass of Str is export where { 0 < .chars <= 512 };

# vim: set filetype=perl6 foldmethod=marker foldlevel=0 nowrap:
