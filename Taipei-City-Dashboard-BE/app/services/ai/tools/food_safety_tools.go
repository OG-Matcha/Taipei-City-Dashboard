package tools

import (
	"TaipeiCityDashboardBE/app/models"
	"context"
	"fmt"
	"strings"
)

// FoodSafetyArgs is the common argument struct for food safety tools.
type FoodSafetyArgs struct {
	City string `json:"city"` // "taipei" or "metrotaipei"
}

func init() {
	Register("get_rfsrai_ranking", GetRfsraiRanking)
	Register("get_inspection_failures", GetInspectionFailures)
}

// fetchTwoDRows fetches the embedded SQL from query_charts and executes it on DBDashboard.
func fetchTwoDRows(index, city string) ([]models.TwoDimensionalData, error) {
	var qc struct {
		QueryChart string `gorm:"column:query_chart"`
	}
	err := models.DBManager.
		Table("query_charts").
		Select("query_chart").
		Where("index = ? AND city = ?", index, city).
		First(&qc).Error
	if err != nil {
		return nil, fmt.Errorf("query_charts lookup failed: %w", err)
	}

	var rows []models.TwoDimensionalData
	err = models.DBDashboard.Raw(qc.QueryChart).Scan(&rows).Error
	if err != nil {
		return nil, fmt.Errorf("data query failed: %w", err)
	}
	return rows, nil
}

// cityLabel returns a display name for the city parameter.
func cityLabel(city string) string {
	if city == "metrotaipei" {
		return "雙北"
	}
	return "臺北市"
}

// GetRfsraiRanking returns the RFSRAI district risk ranking.
// Args: {"city": "taipei" | "metrotaipei"}
func GetRfsraiRanking(ctx context.Context, args string) (string, error) {
	var params FoodSafetyArgs
	if err := parseArgs(args, &params); err != nil {
		params.City = "taipei"
	}
	if params.City == "" {
		params.City = "taipei"
	}

	rows, err := fetchTwoDRows("rfsrai_index", params.City)
	if err != nil {
		return "", fmt.Errorf("取得 RFSRAI 資料失敗: %w", err)
	}
	if len(rows) == 0 {
		return "目前無 RFSRAI 資料。", nil
	}

	var sb strings.Builder
	fmt.Fprintf(&sb, "【%s 區域食品安全風險評估指標 (RFSRAI) 排行】\n", cityLabel(params.City))
	fmt.Fprintf(&sb, "指數越高代表食品安全管理優先程度越高，共 %d 個行政區：\n", len(rows))
	for i, r := range rows {
		fmt.Fprintf(&sb, "%2d. %s — %.2f pts\n", i+1, r.Xaxis, r.Data)
	}
	return sb.String(), nil
}

// GetInspectionFailures returns food inspection failure counts by district.
// Args: {"city": "taipei" | "metrotaipei"}
func GetInspectionFailures(ctx context.Context, args string) (string, error) {
	var params FoodSafetyArgs
	if err := parseArgs(args, &params); err != nil {
		params.City = "taipei"
	}
	if params.City == "" {
		params.City = "taipei"
	}

	rows, err := fetchTwoDRows("food_inspection_failures", params.City)
	if err != nil {
		return "", fmt.Errorf("取得抽驗不合格資料失敗: %w", err)
	}
	if len(rows) == 0 {
		return "目前無食品抽驗不合格資料。", nil
	}

	var total float64
	for _, r := range rows {
		total += r.Data
	}

	var sb strings.Builder
	fmt.Fprintf(&sb, "【%s 食品抽驗不合格筆數（依行政區）】\n", cityLabel(params.City))
	fmt.Fprintf(&sb, "共 %d 個行政區，總計 %.0f 筆不合格：\n", len(rows), total)
	for _, r := range rows {
		pct := r.Data / total * 100
		fmt.Fprintf(&sb, "  %s：%.0f 筆 (%.1f%%)\n", r.Xaxis, r.Data, pct)
	}
	return sb.String(), nil
}
