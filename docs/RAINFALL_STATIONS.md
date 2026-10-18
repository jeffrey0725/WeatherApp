# Rainfall station coordinates

Last updated: 2026-10-18 22:15:26 HKT (UTC+08:00)

## Source and verification

The rainfall map uses static WGS84 station locations from HKO’s official CSDI spatial version of “Rainfall in the past hour”. Only station metadata is bundled; rainfall measurements always come from fresh `hourlyRainfall.php` requests. This catalog is separate from temperature stations and SwiftData favorite IDs.

Verified on **2026-10-18, Asia/Hong_Kong**: all 36 spatial records were matched to the English hourly API feed by the station ID in each `data_url` filename and by station name (normalizing straight/curly apostrophes). All 36 IDs and names matched. The linked Sha Tin and Shui Pin Wai JSON endpoints were also retrieved successfully. No weather readings from this verification are bundled.

Sources:

- [Official HKO rainfall dataset](https://data.gov.hk/en-data/dataset/hk-hko-rss-rainfall-in-the-past-hour).
- [Official spatial resource](https://data.gov.hk/en-data/dataset/hk-hko-rss-rainfall-in-the-past-hour/resource/ec2d37a2-6a69-4c70-b3f1-f14792a68612).
- [CSDI dataset viewer](https://portal.csdi.gov.hk/geoportal/?datasetId=hko_rcd_1666097185091_14408&lang=en).
- [WFS capabilities](https://portal.csdi.gov.hk/server/services/common/hko_rcd_1666097185091_14408/MapServer/WFSServer?service=WFS&request=GetCapabilities).
- [Spatial GeoJSON records](https://portal.csdi.gov.hk/server/services/common/hko_rcd_1666097185091_14408/MapServer/WFSServer?service=WFS&version=2.0.0&request=GetFeature&typeNames=csdi:hourlyRainfall&outputFormat=GEOJSON&count=100).
- [Hourly rainfall API, English](https://data.weather.gov.hk/weatherAPI/opendata/hourlyRainfall.php?lang=en).

## Identity rule

**The spatial layer’s `automaticWeatherStationID` is not the hourly API’s station ID.** For example, spatial `RF003` means Shui Pin Wai, whose linked file is `rf_hourly_N12.json`; spatial `RF022` means Sha Tin, whose linked file is `rf_hourly_RF020.json`. Joining on the spatial ID would place many readings at the wrong locations.

Use the `rf_hourly_<API ID>.json` filename in the spatial record’s HKO `data_url`, and verify the English/Chinese station names before updating the catalog. GeoJSON coordinate order is `[longitude, latitude]`; the Swift catalog below stores named `latitude` and `longitude` fields. Do not join to the temperature catalog by similar names.

Unknown future API IDs retain their readings and names in List, with their unverified-location count shown in Map. They are not assigned estimated coordinates. New IDs require a separate metadata verification.

## Verified crosswalk

These locations are implemented in [RainfallStationCatalog.swift](../WeatherApp/StaticFile/RainfallStationCatalog.swift). Coordinate precision below preserves the published GeoJSON values; it does not represent a measured positioning accuracy.

| Hourly API ID / data filename suffix | Spatial layer ID | Station | Latitude | Longitude |
| --- | --- | --- | --- | --- |
| RF001 | RF001 | Lau Fau Shan / 流浮山 | 22.46888889 | 113.98361111 |
| RF002 | RF002 | Wetland Park / 濕地公園 | 22.46666667 | 114.00888889 |
| N12 | RF003 | Shui Pin Wai / 水邊圍 | 22.44614626 | 114.02096340 |
| RF003 | RF004 | Shek Kong / 石崗 | 22.43611111 | 114.08472222 |
| RF004 | RF005 | Tai Mei Tuk / 大美督 | 22.47527778 | 114.23750000 |
| RF005 | RF006 | Tai Po Market / 大埔墟 | 22.44555556 | 114.17166667 |
| RF006 | RF007 | Pak Tam Chung / 北潭涌 | 22.40277778 | 114.32305556 |
| RF007 | RF008 | Kau Sai Chau / 滘西洲 | 22.37027778 | 114.31250000 |
| N15 | RF009 | Sai Kung / 西貢 | 22.38261834 | 114.27028350 |
| RF008 | RF010 | Tseung Kwan O / 將軍澳 | 22.31583333 | 114.25555556 |
| RF009 | RF011 | Clear Water Bay / 清水灣 | 22.26333333 | 114.29972222 |
| RF010 | RF012 | Waglan Island / 橫瀾島 | 22.18222222 | 114.30333333 |
| RF011 | RF013 | Cheung Chau / 長洲 | 22.20111111 | 114.02666667 |
| RF012 | RF014 | Peng Chau / 坪洲 | 22.29111111 | 114.04333333 |
| RF013 | RF015 | Ngong Ping / 昂坪 | 22.25555556 | 113.91138890 |
| RF014 | RF016 | Hong Kong International Airport / 香港國際機場 | 22.30944444 | 113.92194444 |
| RF015 | RF017 | Ta Kwu Ling / 打鼓嶺 | 22.52861111 | 114.15666667 |
| RF016 | RF018 | Sheung Shui / 上水 | 22.50194444 | 114.11111111 |
| RF017 | RF019 | Tai Lung / 大隴 | 22.48472222 | 114.11750000 |
| RF018 | RF020 | Tsuen Wan Ho Koon / 荃灣可觀 | 22.38361111 | 114.10777778 |
| RF019 | RF021 | Tuen Mun / 屯門 | 22.38583333 | 113.96416667 |
| RF020 | RF022 | Sha Tin / 沙田 | 22.40250000 | 114.21000000 |
| RF021 | RF023 | Cheung Ching / 長青 | 22.34805556 | 114.10916667 |
| RF022 | RF024 | Sham Shui Po / 深水埗 | 22.33583333 | 114.13694444 |
| RF023 | RF025 | Hong Kong Observatory / 香港天文台 | 22.30194444 | 114.17416667 |
| RF024 | RF026 | King’s Park / 京士柏 | 22.31194444 | 114.17277778 |
| K02 | RF027 | Broadcast Drive / 廣播道 | 22.34299050 | 114.17892222 |
| RF025 | RF028 | Kai Tak / 啟德 | 22.30972222 | 114.21333333 |
| K09 | RF029 | San Po Kong / 新蒲崗 | 22.33257776 | 114.19570500 |
| K03 | RF030 | Kwun Tong / 觀塘 | 22.31861151 | 114.22461660 |
| RF026 | RF031 | Shau Kei Wan / 筲箕灣 | 22.28166667 | 114.23611111 |
| RF027 | RF032 | Happy Valley / 跑馬地 | 22.27055556 | 114.18361111 |
| RF028 | RF033 | The Peak / 山頂 | 22.26416667 | 114.15500000 |
| H17 | RF034 | Magazine Gap / 馬己仙峽 | 22.27173028 | 114.16407860 |
| H15 | RF035 | Stanley / 赤柱 | 22.21557006 | 114.21565990 |
| H24 | RF036 | Wong Chuk Hang / 黄竹坑 | 22.25126785 | 114.17355890 |

## Maintenance and validation

When reviewing a future spatial update, retrieve the sources into `.build/validation/`, repeat the filename/name match against the live API, and compare all coordinates with the Swift catalog. Update this crosswalk, its verification date, and the document timestamp together. Preserve unknown/missing/maintenance values as distinct states.

Regression tests cover catalog coverage and Hong Kong bounds, the nonmatching spatial/API ID cases, all eight non-RF API IDs, shared map/list search, unknown IDs, zero/maintenance/unavailable states, and captured reading/interval snapshots. These tests do not establish native map rendering, gestures, or VoiceOver behavior. See [STATUS.md](STATUS.md#validation-record) for the latest test outcome and runtime limits.
