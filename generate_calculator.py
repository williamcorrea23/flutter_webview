import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

def build_calculator(output_path):
    wb = openpyxl.Workbook()
    
    # -------------------------------------------------------------
    # STYLES & PALETTE
    # -------------------------------------------------------------
    font_family = "Segoe UI"
    
    c_header_navy = "003366"
    c_header_slate = "1E293B"
    c_accent_blue = "0284C7"
    c_accent_green = "059669"
    c_input_yellow = "FEF9C3"
    
    font_title = Font(name=font_family, size=15, bold=True, color="FFFFFF")
    font_subtitle = Font(name=font_family, size=9.5, italic=True, color="E2E8F0")
    font_section = Font(name=font_family, size=11, bold=True, color="003366")
    font_tbl_header = Font(name=font_family, size=9.5, bold=True, color="FFFFFF")
    font_tbl_row = Font(name=font_family, size=9.5, color="0F172A")
    font_tbl_bold = Font(name=font_family, size=9.5, bold=True, color="0F172A")
    font_highlight_green = Font(name=font_family, size=9.5, bold=True, color="047857")
    font_note = Font(name=font_family, size=8.5, italic=True, color="64748B")
    
    fill_header_navy = PatternFill(start_color=c_header_navy, end_color=c_header_navy, fill_type="solid")
    fill_header_slate = PatternFill(start_color=c_header_slate, end_color=c_header_slate, fill_type="solid")
    fill_accent_blue = PatternFill(start_color=c_accent_blue, end_color=c_accent_blue, fill_type="solid")
    fill_accent_green = PatternFill(start_color="D1FAE5", end_color="D1FAE5", fill_type="solid")
    fill_input = PatternFill(start_color=c_input_yellow, end_color=c_input_yellow, fill_type="solid")
    fill_total = PatternFill(start_color="E2E8F0", end_color="E2E8F0", fill_type="solid")
    
    border_thin = Side(style="thin", color="CBD5E1")
    border_medium = Side(style="medium", color="94A3B8")
    border_double = Side(style="double", color="003366")
    
    cell_border = Border(left=border_thin, right=border_thin, top=border_thin, bottom=border_thin)
    header_border = Border(left=border_thin, right=border_thin, top=border_medium, bottom=border_medium)
    total_border = Border(top=border_thin, bottom=border_double)
    
    align_left = Alignment(horizontal="left", vertical="center")
    align_right = Alignment(horizontal="right", vertical="center")
    align_center = Alignment(horizontal="center", vertical="center")
    
    fmt_currency_usd = "$#,##0.00"
    fmt_currency_usd_4dec = "$#,##0.0000"
    fmt_currency_brl = "R$ #,##0.00"
    fmt_currency_inr = "₹#,##0.00"
    fmt_int = "#,##0"
    fmt_percent = "0.0%"
    fmt_decimal = "0.0000"

    # =============================================================
    # SHEET 1: PREMISSAS & PAINEL DE CONTROLE (MATRIZ 6 PAÍSES)
    # =============================================================
    ws_inputs = wb.active
    ws_inputs.title = "Premissas & Controle"
    ws_inputs.views.sheetView[0].showGridLines = True
    
    # Title Banner
    ws_inputs.merge_cells("B2:K2")
    ws_inputs["B2"] = "PAINEL DE PREMISSAS, TEMPO DE USO & MATRIZ GLOBAL (6 PAÍSES: BR, EUA, DE, PT, CA, IN)"
    ws_inputs["B2"].font = font_title
    ws_inputs["B2"].fill = fill_header_navy
    ws_inputs["B2"].alignment = align_center
    ws_inputs.row_dimensions[2].height = 34
    
    ws_inputs.merge_cells("B3:K3")
    ws_inputs["B3"] = "Monetização por tempo de uso de anúncios, custos de mídia paga (CPI/CAC) e conversores multi-moeda."
    ws_inputs["B3"].font = font_subtitle
    ws_inputs["B3"].fill = fill_header_navy
    ws_inputs["B3"].alignment = align_center
    ws_inputs.row_dimensions[3].height = 20

    # Section 1: Conversores de Câmbio Multi-Moeda (BRL / USD / INR / EUR)
    ws_inputs["B5"] = "1. CONVERSORES DE MOEDA (USD, BRL, INR & EUR)"
    ws_inputs["B5"].font = font_section
    
    inputs_macro = [
        ("Câmbio Dólar / Real (USD / BRL)", 5.50, fmt_currency_usd, "B6", "C6", "Cotação do Dólar em Reais (R$)"),
        ("Câmbio Dólar / Rúpia Indiana (USD / INR)", 83.50, fmt_decimal, "B7", "C7", "Cotação do Dólar em Rúpias Indianas (₹ INR)"),
        ("Câmbio Euro / Dólar (EUR / USD)", 1.08, fmt_currency_usd, "B8", "C8", "Cotação do Euro em Dólares para Alemanha e Portugal"),
        ("Inverso: Câmbio Real / Dólar (BRL / USD)", "=1/C6", fmt_currency_usd, "B9", "C9", "Fórmula: 1 / (USD/BRL)"),
        ("Inverso: Câmbio Rúpia / Dólar (INR / USD)", "=1/C7", fmt_decimal, "B10", "C10", "Fórmula: 1 / (USD/INR)"),
        ("Taxa de Impostos / Retenção Efetiva (Brasil)", 0.08, fmt_percent, "B11", "C11", "Alíquota estimada Simples/Presumido exportação"),
    ]
    for label, val, num_fmt, cell_lbl, cell_val, desc in inputs_macro:
        ws_inputs[cell_lbl] = label
        ws_inputs[cell_lbl].font = font_tbl_bold
        ws_inputs[cell_val] = val
        ws_inputs[cell_val].font = font_tbl_bold
        if "C9" in cell_val or "C10" in cell_val:
            ws_inputs[cell_val].font = font_highlight_green
        else:
            ws_inputs[cell_val].fill = fill_input
        ws_inputs[cell_val].number_format = num_fmt
        ws_inputs[cell_val].border = cell_border
        ws_inputs[cell_val].alignment = align_right
        ws_inputs[f"D{cell_val[1:]}"] = desc
        ws_inputs[f"D{cell_val[1:]}"].font = font_note

    # Section 2: MATRIZ DE ANÚNCIOS POR TEMPO DE USO E MÍDIA PAGA (6 PAÍSES)
    ws_inputs["B13"] = "2. MATRIZ DE MONETIZAÇÃO DE ANÚNCIOS POR TEMPO DE USO & PROPAGANDA PAGA (6 PAÍSES)"
    ws_inputs["B13"].font = font_section

    matrix_headers = [
        "País / Mercado", "Mix Tráfego (%)", "eCPM Intersticial ($)", "eCPM Banner ($)", 
        "Receita 10 min ($)", "Receita 30 min ($)", "Receita 1 hora ($)", "ARPU Ads Mensal ($)", 
        "CPI Google Ads ($)", "CAC B2B Desktop ($)"
    ]
    ws_inputs.row_dimensions[15].height = 28
    for col_idx, h in enumerate(matrix_headers, start=2):
        c = ws_inputs.cell(row=15, column=col_idx, value=h)
        c.font = font_tbl_header
        c.fill = fill_header_slate
        c.alignment = align_center
        c.border = header_border

    countries_data = [
        ("Índia (IN)", 0.65, 0.95, 0.12, 0.09, 12.00),
        ("Brasil (BR)", 0.15, 2.40, 0.32, 0.22, 16.00),
        ("Estados Unidos (EUA)", 0.07, 11.50, 1.45, 2.30, 44.00),
        ("Alemanha (DE)", 0.06, 10.20, 1.30, 1.85, 38.00),
        ("Canadá (CA)", 0.04, 9.50, 1.25, 1.95, 39.00),
        ("Portugal (PT)", 0.03, 4.10, 0.55, 0.65, 24.00),
    ]

    for idx, (country, mix, ecpm_int, ecpm_ban, cpi, cac) in enumerate(countries_data, start=16):
        ws_inputs.cell(row=idx, column=2, value=country).font = font_tbl_bold
        ws_inputs.cell(row=idx, column=2).border = cell_border
        
        # Mix %
        c_mix = ws_inputs.cell(row=idx, column=3, value=mix)
        c_mix.font = font_tbl_bold
        c_mix.number_format = fmt_percent
        c_mix.alignment = align_right
        c_mix.border = cell_border
        c_mix.fill = fill_input
        
        # eCPM Intersticial
        c_int = ws_inputs.cell(row=idx, column=4, value=ecpm_int)
        c_int.font = font_tbl_bold
        c_int.number_format = fmt_currency_usd
        c_int.alignment = align_right
        c_int.border = cell_border
        c_int.fill = fill_input
        
        # eCPM Banner
        c_ban = ws_inputs.cell(row=idx, column=5, value=ecpm_ban)
        c_ban.font = font_tbl_bold
        c_ban.number_format = fmt_currency_usd
        c_ban.alignment = align_right
        c_ban.border = cell_border
        c_ban.fill = fill_input
        
        # Receita 10 min: (4/1000)*eCPM_Int + (10/1000)*eCPM_Ban
        c_10m = ws_inputs.cell(row=idx, column=6, value=f"=(4/1000)*D{idx} + (10/1000)*E{idx}")
        c_10m.font = font_tbl_row
        c_10m.number_format = fmt_currency_usd_4dec
        c_10m.alignment = align_right
        c_10m.border = cell_border
        
        # Receita 30 min: (12/1000)*eCPM_Int + (30/1000)*eCPM_Ban
        c_30m = ws_inputs.cell(row=idx, column=7, value=f"=(12/1000)*D{idx} + (30/1000)*E{idx}")
        c_30m.font = font_tbl_row
        c_30m.number_format = fmt_currency_usd_4dec
        c_30m.alignment = align_right
        c_30m.border = cell_border
        
        # Receita 1 hora: (25/1000)*eCPM_Int + (60/1000)*eCPM_Ban
        c_1h = ws_inputs.cell(row=idx, column=8, value=f"=(25/1000)*D{idx} + (60/1000)*E{idx}")
        c_1h.font = font_tbl_bold
        c_1h.number_format = fmt_currency_usd
        c_1h.alignment = align_right
        c_1h.border = cell_border
        
        # ARPU Mensal MAU: (56/1000)*eCPM_Int + (154/1000)*eCPM_Ban
        c_mau = ws_inputs.cell(row=idx, column=9, value=f"=(56/1000)*D{idx} + (154/1000)*E{idx}")
        c_mau.font = font_highlight_green
        c_mau.number_format = fmt_currency_usd
        c_mau.alignment = align_right
        c_mau.border = cell_border
        
        # CPI Google Ads
        c_cpi = ws_inputs.cell(row=idx, column=10, value=cpi)
        c_cpi.font = font_tbl_bold
        c_cpi.number_format = fmt_currency_usd
        c_cpi.alignment = align_right
        c_cpi.border = cell_border
        c_cpi.fill = fill_input
        
        # CAC B2B Desktop
        c_cac = ws_inputs.cell(row=idx, column=11, value=cac)
        c_cac.font = font_tbl_bold
        c_cac.number_format = fmt_currency_usd
        c_cac.alignment = align_right
        c_cac.border = cell_border
        c_cac.fill = fill_input

    # Row 22: Linha de Totais Ponderados Globais (BLENDED)
    ws_inputs.cell(row=22, column=2, value="MÉDIA PONDERADA GLOBAL (BLENDED)").font = font_tbl_bold
    ws_inputs.cell(row=22, column=2).border = total_border
    
    c_tot_mix = ws_inputs.cell(row=22, column=3, value="=SUM(C16:C21)")
    c_tot_mix.font = font_tbl_bold
    c_tot_mix.number_format = fmt_percent
    c_tot_mix.alignment = align_right
    c_tot_mix.border = total_border
    
    c_bl_int = ws_inputs.cell(row=22, column=4, value="=SUMPRODUCT(C16:C21, D16:D21)")
    c_bl_int.font = font_highlight_green
    c_bl_int.number_format = fmt_currency_usd
    c_bl_int.alignment = align_right
    c_bl_int.border = total_border
    
    c_bl_ban = ws_inputs.cell(row=22, column=5, value="=SUMPRODUCT(C16:C21, E16:E21)")
    c_bl_ban.font = font_highlight_green
    c_bl_ban.number_format = fmt_currency_usd
    c_bl_ban.alignment = align_right
    c_bl_ban.border = total_border
    
    c_bl_10m = ws_inputs.cell(row=22, column=6, value="=SUMPRODUCT(C16:C21, F16:F21)")
    c_bl_10m.font = font_tbl_bold
    c_bl_10m.number_format = fmt_currency_usd_4dec
    c_bl_10m.alignment = align_right
    c_bl_10m.border = total_border
    
    c_bl_30m = ws_inputs.cell(row=22, column=7, value="=SUMPRODUCT(C16:C21, G16:G21)")
    c_bl_30m.font = font_tbl_bold
    c_bl_30m.number_format = fmt_currency_usd_4dec
    c_bl_30m.alignment = align_right
    c_bl_30m.border = total_border
    
    c_bl_1h = ws_inputs.cell(row=22, column=8, value="=SUMPRODUCT(C16:C21, H16:H21)")
    c_bl_1h.font = font_tbl_bold
    c_bl_1h.number_format = fmt_currency_usd
    c_bl_1h.alignment = align_right
    c_bl_1h.border = total_border
    
    c_bl_mau = ws_inputs.cell(row=22, column=9, value="=SUMPRODUCT(C16:C21, I16:I21)")
    c_bl_mau.font = font_section
    c_bl_mau.number_format = fmt_currency_usd
    c_bl_mau.alignment = align_right
    c_bl_mau.border = total_border
    c_bl_mau.fill = fill_accent_green
    
    c_bl_cpi = ws_inputs.cell(row=22, column=10, value="=SUMPRODUCT(C16:C21, J16:J21)")
    c_bl_cpi.font = font_highlight_green
    c_bl_cpi.number_format = fmt_currency_usd
    c_bl_cpi.alignment = align_right
    c_bl_cpi.border = total_border
    
    c_bl_cac = ws_inputs.cell(row=22, column=11, value="=SUMPRODUCT(C16:C21, K16:K21)")
    c_bl_cac.font = font_highlight_green
    c_bl_cac.number_format = fmt_currency_usd
    c_bl_cac.alignment = align_right
    c_bl_cac.border = total_border

    # Section 3: Produtos & Preços
    ws_inputs["B25"] = "3. PRODUTOS, ASSINATURAS & MOTOR DE IA (RAILWAY + CREWAI + DEEPSEEK FLASH V4)"
    ws_inputs["B25"].font = font_section
    
    inputs_prod = [
        ("Preço Assinatura Mobile ($ USD)", 9.00, fmt_currency_usd, "Assinatura mensal sem anúncios nos 6 apps móveis"),
        ("Comissão Google Play Store", 0.15, fmt_percent, "Taxa para desenvolvedores até $1M anual"),
        ("Razão P.A. de Downloads Mobile por App / Mês", 500, fmt_int, "Novos downloads mensais por aplicativo"),
        ("Razão P.A. de Assinantes Pagantes por App / Mês", 5, fmt_int, "Novos assinantes de $9/mês (1% de conversão)"),
        ("Copilot Desktop - Preço Plano Índia ($ USD)", 7.00, fmt_currency_usd, "Preço com desconto de paridade de compra"),
        ("Copilot Desktop - Preço Plano Índia em Rúpias (₹ INR)", "=C30*C7", fmt_currency_inr, "Fórmula dinâmica: $7 * Câmbio USD/INR (~₹584 INR)"),
        ("Copilot Desktop - Preço Brasil ($ USD)", 15.00, fmt_currency_usd, "Preço profissional no Brasil (~R$ 82,50)"),
        ("Copilot Desktop - Preço Europa/Portugal (€ EUR)", 15.00, fmt_currency_usd, "Preço profissional em Euros para PT/DE"),
        ("Copilot Desktop - Preço EUA/Alemanha/Canadá Power ($ USD)", 25.00, fmt_currency_usd, "Plano avançado para alta intensidade de agentes"),
        ("Tíquete Médio Ponderado Global Desktop ($ USD)", "=(C16*C30 + C17*C32 + C21*C33 + (C18+C19+C20)*C34) / C22", fmt_currency_usd, "Fórmula dinâmica ponderada pelo mix dos 6 países"),
        ("Taxa Processamento Stripe/Paddle", 0.04, fmt_percent, "Taxa de gateway de pagamento"),
        ("Custo IA DeepSeek Flash V4 por Tarefa CrewAI (4 Chamadas) ($)", 0.002137, fmt_decimal, "Pipeline 4 agentes em loop (Input $0.14 / Cache Hit $0.0028 / Output $0.28)"),
        ("Custo Mensal por Usuário Desktop Free ($)", 0.035, fmt_decimal, "Cota de 5 chamadas/dia no Plano Gratuito (DeepSeek Flash V4)"),
        ("Monetização / ARPU Mensal do Usuário Desktop Free ($)", 0.08, fmt_currency_usd, "Parcerias/Sponsored tools no Desktop Free"),
        ("Extensão Chrome Light - Preço Índia ($ USD)", 4.00, fmt_currency_usd, "Assinatura econômica no navegador"),
        ("Extensão Chrome Light - Preço Global ($ USD)", 8.00, fmt_currency_usd, "Assinatura global para EUA, Europa e Canadá"),
        ("Extensão Chrome Light - ARPU Ads Usuário Free ($)", 0.12, fmt_currency_usd, "Banners e links no Side Panel do Chrome"),
    ]

    for idx, (label, val, num_fmt, desc) in enumerate(inputs_prod, start=26):
        ws_inputs[f"B{idx}"] = label
        ws_inputs[f"B{idx}"].font = font_tbl_row
        ws_inputs[f"C{idx}"] = val
        ws_inputs[f"C{idx}"].font = font_tbl_bold
        if "C31" in f"C{idx}" or "C35" in f"C{idx}":
            ws_inputs[f"C{idx}"].font = font_highlight_green
        else:
            ws_inputs[f"C{idx}"].fill = fill_input
        ws_inputs[f"C{idx}"].number_format = num_fmt
        ws_inputs[f"C{idx}"].border = cell_border
        ws_inputs[f"C{idx}"].alignment = align_right
        ws_inputs[f"D{idx}"] = desc
        ws_inputs[f"D{idx}"].font = font_note

    ws_inputs.column_dimensions["A"].width = 3
    ws_inputs.column_dimensions["B"].width = 46
    ws_inputs.column_dimensions["C"].width = 16
    ws_inputs.column_dimensions["D"].width = 22
    ws_inputs.column_dimensions["E"].width = 18
    ws_inputs.column_dimensions["F"].width = 18
    ws_inputs.column_dimensions["G"].width = 18
    ws_inputs.column_dimensions["H"].width = 18
    ws_inputs.column_dimensions["I"].width = 20
    ws_inputs.column_dimensions["J"].width = 18
    ws_inputs.column_dimensions["K"].width = 18

    # =============================================================
    # SHEET 2: SIMULADOR DEDICADO: USUÁRIO X TEMPO X PAÍS
    # =============================================================
    ws_sim = wb.create_sheet(title="Simulador Tempo x País")
    ws_sim.views.sheetView[0].showGridLines = True
    
    ws_sim.merge_cells("B2:J2")
    ws_sim["B2"] = "SIMULADOR DINÂMICO: RECEITA DE ANÚNCIOS POR USUÁRIO X TEMPO DE USO X PAÍS"
    ws_sim["B2"].font = font_title
    ws_sim["B2"].fill = fill_header_navy
    ws_sim["B2"].alignment = align_center
    ws_sim.row_dimensions[2].height = 34
    
    ws_sim.merge_cells("B3:J3")
    ws_sim["B3"] = "Altere a base de usuários e os minutos de uso para calcular a receita exata em cada país."
    ws_sim["B3"].font = font_subtitle
    ws_sim["B3"].fill = fill_header_navy
    ws_sim["B3"].alignment = align_center
    ws_sim.row_dimensions[3].height = 20

    # Section A: Calculadora Instantânea Customizável
    ws_sim["B5"] = "A. CALCULADORA INTERATIVA CUSTOMIZÁVEL"
    ws_sim["B5"].font = font_section

    sim_controls = [
        ("Base de Usuários Simulada (Quantidade de Usuários)", 1000, fmt_int, "B6", "C6", "Digite qualquer quantidade de usuários para simular"),
        ("Tempo Médio de Uso por Sessão (Minutos)", 15, fmt_int, "B7", "C7", "Ex: 10, 15, 30 ou 60 minutos por sessão"),
        ("Sessões / Dias Ativos no Mês por Usuário", 14, fmt_int, "B8", "C8", "Média de dias no mês em que o usuário abre o aplicativo"),
        ("Tempo Total de Uso no Mês por Usuário (Minutos)", "=C7*C8", fmt_int, "B9", "C9", "Fórmula: Minutos por Sessão * Dias no Mês"),
        ("Banners Exibidos por Usuário no Mês", "=C9", fmt_int, "B10", "C10", "Fórmula: 1 banner a cada 1 minuto de tela ativa"),
        ("Intersticiais Exibidos por Usuário no Mês", "=ROUNDDOWN((C9/1.5)*0.85, 0)", fmt_int, "B11", "C11", "Fórmula: 1 intersticial a cada 90s (1,5 min) com 85% fill-rate"),
    ]

    for label, val, num_fmt, cell_lbl, cell_val, desc in sim_controls:
        ws_sim[cell_lbl] = label
        ws_sim[cell_lbl].font = font_tbl_bold
        ws_sim[cell_val] = val
        ws_sim[cell_val].font = font_tbl_bold
        if cell_val in ["C6", "C7", "C8"]:
            ws_sim[cell_val].fill = fill_input
        else:
            ws_sim[cell_val].font = font_highlight_green
        ws_sim[cell_val].number_format = num_fmt
        ws_sim[cell_val].border = cell_border
        ws_sim[cell_val].alignment = align_right
        ws_sim[f"D{cell_val[1:]}"] = desc
        ws_sim[f"D{cell_val[1:]}"].font = font_note

    # Tabela de Resultados por País da Simulação Customizada
    ws_sim["B13"] = "RESULTADO DA SIMULAÇÃO: DISTRIBUIÇÃO REAL PELO MIX DE TRÁFEGO"
    ws_sim["B13"].font = font_section

    res_headers = [
        "País / Mercado", "Mix Tráfego (%)", "Usuários Ativos no País", "Receita por 1 Usuário ($)", 
        "Receita Total País (USD $)", "Receita Total País (BRL R$)", "Receita Total País (INR ₹)", 
        "Participação na Receita (%)", "Observação Estratégica"
    ]
    ws_sim.row_dimensions[14].height = 25
    for c_idx, h in enumerate(res_headers, start=2):
        c = ws_sim.cell(row=14, column=c_idx, value=h)
        c.font = font_tbl_header
        c.fill = fill_header_slate
        c.alignment = align_center
        c.border = header_border

    # Countries mapping to Sheet 1 row numbers:
    # India = 16, Brasil = 17, Portugal = 21, Canada = 20, Alemanha = 19, EUA = 18
    sim_countries = [
        ("Índia (IN)", 16, "Base massiva de volume e testes"),
        ("Brasil (BR)", 17, "Mercado doméstico com baixo CPI"),
        ("Portugal (PT)", 21, "Porta de entrada na Europa em PT"),
        ("Canadá (CA)", 20, "Alto poder de compra corporativo"),
        ("Alemanha (DE)", 19, "Coração mundial e sede da SAP"),
        ("Estados Unidos (EUA)", 18, "Maior retorno unitário de anúncios"),
    ]

    for idx, (country, s1_row, obs) in enumerate(sim_countries, start=15):
        # País / Mercado
        ws_sim.cell(row=idx, column=2, value=country).font = font_tbl_bold
        ws_sim.cell(row=idx, column=2).border = cell_border
        
        # Mix Tráfego (%): link direto com Premissas!C{s1_row}
        c_mix = ws_sim.cell(row=idx, column=3, value=f"='Premissas & Controle'!C{s1_row}")
        c_mix.font = font_tbl_bold
        c_mix.number_format = fmt_percent
        c_mix.alignment = align_right
        c_mix.border = cell_border
        
        # Usuários Ativos no País: Base Total $C$6 * Mix C{idx}
        c_users = ws_sim.cell(row=idx, column=4, value=f"=ROUND($C$6 * C{idx}, 0)")
        c_users.font = font_tbl_bold
        c_users.number_format = fmt_int
        c_users.alignment = align_right
        c_users.border = cell_border
        
        # Receita por 1 Usuário ($): (Intersticiais/1000)*eCPM_Int + (Banners/1000)*eCPM_Ban
        c_1u = ws_sim.cell(row=idx, column=5, value=f"=($C$11/1000)*'Premissas & Controle'!D{s1_row} + ($C$10/1000)*'Premissas & Controle'!E{s1_row}")
        c_1u.font = font_tbl_row
        c_1u.number_format = fmt_currency_usd_4dec
        c_1u.alignment = align_right
        c_1u.border = cell_border
        
        # Receita Total País (USD $): Usuários do País D{idx} * Receita 1 Usuário E{idx}
        c_tot_usd = ws_sim.cell(row=idx, column=6, value=f"=D{idx} * E{idx}")
        c_tot_usd.font = font_tbl_bold
        c_tot_usd.number_format = fmt_currency_usd
        c_tot_usd.alignment = align_right
        c_tot_usd.border = cell_border

        # Receita Total País (BRL R$): Receita_USD F{idx} * Câmbio_USD_BRL
        c_tot_brl = ws_sim.cell(row=idx, column=7, value=f"=F{idx} * 'Premissas & Controle'!$C$6")
        c_tot_brl.font = font_tbl_bold
        c_tot_brl.number_format = fmt_currency_brl
        c_tot_brl.alignment = align_right
        c_tot_brl.border = cell_border

        # Receita Total País (INR ₹): Receita_USD F{idx} * Câmbio_USD_INR
        c_tot_inr = ws_sim.cell(row=idx, column=8, value=f"=F{idx} * 'Premissas & Controle'!$C$7")
        c_tot_inr.font = font_tbl_row
        c_tot_inr.number_format = fmt_currency_inr
        c_tot_inr.alignment = align_right
        c_tot_inr.border = cell_border

        # Participação na Receita (%): Receita_País F{idx} / Total_Global $F$21
        c_part = ws_sim.cell(row=idx, column=9, value=f"=F{idx} / $F$21")
        c_part.font = font_highlight_green
        c_part.number_format = fmt_percent
        c_part.alignment = align_right
        c_part.border = cell_border

        # Observação
        c_obs = ws_sim.cell(row=idx, column=10, value=obs)
        c_obs.font = font_note
        c_obs.alignment = align_left
        c_obs.border = cell_border

    # Row 21: Linha de TOTAL CONSOLIDADO (DISTRIBUÍDO PELO MIX)
    ws_sim.cell(row=21, column=2, value="TOTAL CONSOLIDADO (DISTRIBUÍDO PELO MIX)").font = font_section
    ws_sim.cell(row=21, column=2).border = total_border
    
    # Soma dos Mixes
    c_tot_mix = ws_sim.cell(row=21, column=3, value="=SUM(C15:C20)")
    c_tot_mix.font = font_section
    c_tot_mix.number_format = fmt_percent
    c_tot_mix.alignment = align_right
    c_tot_mix.border = total_border
    c_tot_mix.fill = fill_accent_green

    # Soma dos Usuários = Base Total C6
    c_tot_usr = ws_sim.cell(row=21, column=4, value="=SUM(D15:D20)")
    c_tot_usr.font = font_section
    c_tot_usr.number_format = fmt_int
    c_tot_usr.alignment = align_right
    c_tot_usr.border = total_border
    c_tot_usr.fill = fill_accent_green

    # Receita Média Blended por Usuário = F21 / D21
    c_avg_rev = ws_sim.cell(row=21, column=5, value="=F21 / D21")
    c_avg_rev.font = font_section
    c_avg_rev.number_format = fmt_currency_usd_4dec
    c_avg_rev.alignment = align_right
    c_avg_rev.border = total_border
    c_avg_rev.fill = fill_accent_green

    # Receita Total Consolidada USD = SUM(F15:F20)
    c_tot_rev_usd = ws_sim.cell(row=21, column=6, value="=SUM(F15:F20)")
    c_tot_rev_usd.font = Font(name=font_family, size=11, bold=True, color="047857")
    c_tot_rev_usd.number_format = fmt_currency_usd
    c_tot_rev_usd.alignment = align_right
    c_tot_rev_usd.border = total_border
    c_tot_rev_usd.fill = fill_accent_green

    # Receita Total Consolidada BRL = SUM(G15:G20)
    c_tot_rev_brl = ws_sim.cell(row=21, column=7, value="=SUM(G15:G20)")
    c_tot_rev_brl.font = Font(name=font_family, size=11, bold=True, color="047857")
    c_tot_rev_brl.number_format = fmt_currency_brl
    c_tot_rev_brl.alignment = align_right
    c_tot_rev_brl.border = total_border
    c_tot_rev_brl.fill = fill_accent_green

    # Receita Total Consolidada INR = SUM(H15:H20)
    c_tot_rev_inr = ws_sim.cell(row=21, column=8, value="=SUM(H15:H20)")
    c_tot_rev_inr.font = font_section
    c_tot_rev_inr.number_format = fmt_currency_inr
    c_tot_rev_inr.alignment = align_right
    c_tot_rev_inr.border = total_border

    # Participação Total = 100%
    c_tot_part = ws_sim.cell(row=21, column=9, value="=SUM(I15:I20)")
    c_tot_part.font = font_section
    c_tot_part.number_format = fmt_percent
    c_tot_part.alignment = align_right
    c_tot_part.border = total_border

    # Obs
    c_tot_obs = ws_sim.cell(row=21, column=10, value="Faturamento real respeitando o Mix de Tráfego")
    c_tot_obs.font = font_note
    c_tot_obs.alignment = align_left
    c_tot_obs.border = total_border

    # Section B: MATRIZ BIDIMENSIONAL (RECEITA POR 1 USUÁRIO X TEMPO DE USO X PAÍS)
    ws_sim["B24"] = "B. MATRIZ CRUZADA: RECEITA POR 1 ÚNICO USUÁRIO X TEMPO DE USO (USD $)"
    ws_sim["B24"].font = font_section

    matrix_time_headers = [
        "Tempo de Uso Ativo", "Índia (IN)", "Brasil (BR)", "Portugal (PT)", 
        "Alemanha (DE)", "Canadá (CA)", "EUA (US)", "Média Global (Blended)"
    ]
    ws_sim.row_dimensions[25].height = 25
    for c_idx, h in enumerate(matrix_time_headers, start=2):
        c = ws_sim.cell(row=25, column=c_idx, value=h)
        c.font = font_tbl_header
        c.fill = fill_header_slate
        c.alignment = align_center
        c.border = header_border

    # Durations: (Label, banners, interstitials)
    durations = [
        ("5 minutos (Rápido)", 5, 2),
        ("10 minutos", 10, 4),
        ("15 minutos", 15, 7),
        ("30 minutos (1 lição)", 30, 12),
        ("45 minutos", 45, 18),
        ("1 hora (60 min)", 60, 25),
        ("2 horas (Estudo longo)", 120, 50),
        ("Mês Leve (7 dias x 10 min = 70 min)", 70, 28),
        ("Mês Típico (14 dias x 15 min = 210 min)", 154, 56),
        ("Mês Intensivo (20 dias x 30 min = 600 min)", 600, 220),
    ]

    for d_idx, (d_label, bans, ints) in enumerate(durations, start=26):
        ws_sim.cell(row=d_idx, column=2, value=d_label).font = font_tbl_bold
        ws_sim.cell(row=d_idx, column=2).border = cell_border
        
        # Columns 3 to 9: India (16), Brasil (17), Portugal (21), Alemanha (19), Canada (20), EUA (18), Blended (22)
        target_rows = [16, 17, 21, 19, 20, 18, 22]
        for col_pos, t_row in enumerate(target_rows, start=3):
            is_global = col_pos == 9
            cell = ws_sim.cell(row=d_idx, column=col_pos, value=f"=({ints}/1000)*'Premissas & Controle'!D{t_row} + ({bans}/1000)*'Premissas & Controle'!E{t_row}")
            cell.font = font_highlight_green if is_global else font_tbl_row
            cell.number_format = fmt_currency_usd_4dec
            cell.alignment = align_right
            cell.border = cell_border
            if is_global:
                cell.fill = fill_accent_green

    # Section C: MATRIZ BIDIMENSIONAL (RECEITA DA BASE TOTAL DISTRIBUÍDA PELO MIX EM REAIS R$)
    ws_sim["B38"] = "C. MATRIZ CRUZADA: FATURAMENTO DA BASE SIMULADA (DISTRIBUÍDA PELO MIX) EM REAIS (BRL - R$)"
    ws_sim["B38"].font = font_section

    ws_sim.row_dimensions[39].height = 25
    for c_idx, h in enumerate(matrix_time_headers, start=2):
        c = ws_sim.cell(row=39, column=c_idx, value=h)
        c.font = font_tbl_header
        c.fill = fill_header_navy
        c.alignment = align_center
        c.border = header_border

    for d_idx, (d_label, _, _) in enumerate(durations, start=40):
        src_row = d_idx - 14  # Corresponds to row 26 to 35
        ws_sim.cell(row=d_idx, column=2, value=d_label).font = font_tbl_bold
        ws_sim.cell(row=d_idx, column=2).border = cell_border
        
        # Col 3 to 8: India (C15), Brasil (C16), Portugal (C17), Alemanha (C18), Canada (C19), EUA (C20)
        # Revenue in BRL for the country's share of users:
        # =(Receita_1U * Base_Usuarios_C6 * Mix_Pais) * Cambio_USD_BRL
        country_mix_cells = ["$C$15", "$C$16", "$C$17", "$C$19", "$C$18", "$C$20"]
        for col_pos in range(3, 9):
            col_letter = get_column_letter(col_pos)
            mix_cell = country_mix_cells[col_pos - 3]
            cell = ws_sim.cell(row=d_idx, column=col_pos, value=f"={col_letter}{src_row} * ($C$6 * {mix_cell}) * 'Premissas & Controle'!$C$6")
            cell.font = font_tbl_bold
            cell.number_format = fmt_currency_brl
            cell.alignment = align_right
            cell.border = cell_border

        # Col 9 (Média Global Total): SUM of country revenues
        c_tot = ws_sim.cell(row=d_idx, column=9, value=f"=SUM(C{d_idx}:H{d_idx})")
        c_tot.font = font_section
        c_tot.number_format = fmt_currency_brl
        c_tot.alignment = align_right
        c_tot.border = cell_border
        c_tot.fill = fill_accent_green

    ws_sim.column_dimensions["A"].width = 3
    ws_sim.column_dimensions["B"].width = 46
    ws_sim.column_dimensions["C"].width = 16
    ws_sim.column_dimensions["D"].width = 24
    ws_sim.column_dimensions["E"].width = 24
    ws_sim.column_dimensions["F"].width = 24
    ws_sim.column_dimensions["G"].width = 24
    ws_sim.column_dimensions["H"].width = 24
    ws_sim.column_dimensions["I"].width = 26
    ws_sim.column_dimensions["J"].width = 34

    # =============================================================
    # SHEET 3: CALCULADORA 12 MESES DINÂMICA
    # =============================================================
    ws_calc = wb.create_sheet(title="Calculadora 12 Meses")
    ws_calc.views.sheetView[0].showGridLines = True
    
    ws_calc.merge_cells("B2:O2")
    ws_calc["B2"] = "SIMULADOR FINANCEIRO MÊS A MÊS - ECOSSISTEMA GLOBAL SAP AI (MATRIZ 6 PAÍSES)"
    ws_calc["B2"].font = font_title
    ws_calc["B2"].fill = fill_header_navy
    ws_calc["B2"].alignment = align_center
    ws_calc.row_dimensions[2].height = 34

    months = [f"M{m}" for m in range(1, 13)]
    headers_calc = ["Métrica / Linha de Demonstração"] + months + ["TOTAL ANO 1"]
    
    ws_calc.row_dimensions[4].height = 25
    for col_idx, h in enumerate(headers_calc, start=2):
        cell = ws_calc.cell(row=4, column=col_idx, value=h)
        cell.font = font_tbl_header
        cell.fill = fill_header_slate
        cell.alignment = align_center if col_idx > 2 else align_left
        cell.border = header_border

    def add_sec_header_calc(row, title):
        ws_calc.merge_cells(start_row=row, start_column=2, end_row=row, end_column=15)
        c = ws_calc.cell(row=row, column=2, value=title)
        c.font = Font(name=font_family, size=9.5, bold=True, color="FFFFFF")
        c.fill = fill_accent_blue
        c.alignment = align_left
        ws_calc.row_dimensions[row].height = 20

    # 1. Base de Usuários
    add_sec_header_calc(5, "1. BASE DE USUÁRIOS E CLIENTES (UNIDADES)")
    
    rollout_apps = [1, 3, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6]
    ws_calc.cell(row=6, column=2, value="Apps Móveis Ativos na Suíte").font = font_tbl_row
    for m_idx, apps in enumerate(rollout_apps, start=3):
        c = ws_calc.cell(row=6, column=m_idx, value=apps)
        c.font = font_tbl_bold
        c.alignment = align_center
        c.border = cell_border
    ws_calc.cell(row=6, column=15, value=6).font = font_tbl_bold
    ws_calc.cell(row=6, column=15).alignment = align_center
    ws_calc.cell(row=6, column=15).border = cell_border

    # Usuários Mobile Totais
    ws_calc.cell(row=7, column=2, value="Usuários Ativos Mobile Totais (MAU)").font = font_tbl_row
    ws_calc.cell(row=7, column=3, value="=C6*'Premissas & Controle'!$C$28")
    ws_calc.cell(row=7, column=3).number_format = fmt_int
    ws_calc.cell(row=7, column=3).alignment = align_right
    ws_calc.cell(row=7, column=3).border = cell_border
    for m_idx in range(4, 15):
        col_let = get_column_letter(m_idx)
        prev_let = get_column_letter(m_idx - 1)
        c = ws_calc.cell(row=7, column=m_idx, value=f"={prev_let}7 + {col_let}6*'Premissas & Controle'!$C$28")
        c.number_format = fmt_int
        c.alignment = align_right
        c.border = cell_border
    ws_calc.cell(row=7, column=15, value="=N7").number_format = fmt_int
    ws_calc.cell(row=7, column=15).alignment = align_right
    ws_calc.cell(row=7, column=15).border = cell_border

    # Assinantes Mobile ($9/mês)
    ws_calc.cell(row=8, column=2, value="Assinantes Mobile Pagantes ($9/mês)").font = font_tbl_row
    ws_calc.cell(row=8, column=3, value="=C6*'Premissas & Controle'!$C$29")
    ws_calc.cell(row=8, column=3).number_format = fmt_int
    ws_calc.cell(row=8, column=3).alignment = align_right
    ws_calc.cell(row=8, column=3).border = cell_border
    for m_idx in range(4, 15):
        col_let = get_column_letter(m_idx)
        prev_let = get_column_letter(m_idx - 1)
        c = ws_calc.cell(row=8, column=m_idx, value=f"={prev_let}8 + {col_let}6*'Premissas & Controle'!$C$29")
        c.number_format = fmt_int
        c.alignment = align_right
        c.border = cell_border
    ws_calc.cell(row=8, column=15, value="=N8").number_format = fmt_int
    ws_calc.cell(row=8, column=15).alignment = align_right
    ws_calc.cell(row=8, column=15).border = cell_border

    # Usuários Desktop Free Tier
    ws_calc.cell(row=9, column=2, value="Usuários Ativos Copilot Desktop - PLANO FREE").font = font_tbl_row
    free_desktop_users = [150, 400, 800, 1400, 2200, 3200, 4200, 5200, 6100, 6800, 7400, 8000]
    for m_idx, f_users in enumerate(free_desktop_users, start=3):
        c = ws_calc.cell(row=9, column=m_idx, value=f_users)
        c.font = font_tbl_row
        c.number_format = fmt_int
        c.alignment = align_right
        c.border = cell_border
        c.fill = fill_input
    ws_calc.cell(row=9, column=15, value="=N9").number_format = fmt_int
    ws_calc.cell(row=9, column=15).alignment = align_right
    ws_calc.cell(row=9, column=15).border = cell_border

    # Assinantes Copilot Windows Desktop (Pagantes)
    ws_calc.cell(row=10, column=2, value="Assinantes Copilot Windows Desktop (Pagantes)").font = font_tbl_bold
    desk_subscribers = [35, 80, 160, 260, 400, 600, 800, 1000, 1200, 1350, 1500, 1600]
    for m_idx, subs in enumerate(desk_subscribers, start=3):
        c = ws_calc.cell(row=10, column=m_idx, value=subs)
        c.font = font_tbl_bold
        c.number_format = fmt_int
        c.alignment = align_right
        c.border = cell_border
        c.fill = fill_input
    ws_calc.cell(row=10, column=15, value="=N10").number_format = fmt_int
    ws_calc.cell(row=10, column=15).alignment = align_right
    ws_calc.cell(row=10, column=15).border = cell_border
    ws_calc.cell(row=10, column=15).font = font_tbl_bold

    # Assinantes Extensão Chrome
    ws_calc.cell(row=11, column=2, value="Assinantes Extensão Chrome Light").font = font_tbl_row
    chrome_subscribers = [5, 15, 30, 50, 80, 110, 140, 170, 195, 220, 235, 250]
    for m_idx, subs in enumerate(chrome_subscribers, start=3):
        c = ws_calc.cell(row=11, column=m_idx, value=subs)
        c.font = font_tbl_row
        c.number_format = fmt_int
        c.alignment = align_right
        c.border = cell_border
    ws_calc.cell(row=11, column=15, value="=N11").number_format = fmt_int
    ws_calc.cell(row=11, column=15).alignment = align_right
    ws_calc.cell(row=11, column=15).border = cell_border

    # 2. Receitas Brutas (USD)
    add_sec_header_calc(12, "2. RECEITAS BRUTAS CONSOLIDADAS (USD $)")
    
    # Rec. Ads Mobile: (Total Mobile - Assin Mobile) * ARPU_Mensal_Blended_Sheet1!I22
    ws_calc.cell(row=13, column=2, value="Receita de Anúncios Mobile (AdMob Blended 6 Países)").font = font_tbl_row
    for m_idx in range(3, 15):
        col_let = get_column_letter(m_idx)
        c = ws_calc.cell(row=13, column=m_idx, value=f"=({col_let}7 - {col_let}8) * 'Premissas & Controle'!$I$22")
        c.number_format = fmt_currency_usd
        c.alignment = align_right
        c.border = cell_border
    ws_calc.cell(row=13, column=15, value="=SUM(C13:N13)").number_format = fmt_currency_usd
    ws_calc.cell(row=13, column=15).font = font_tbl_bold
    ws_calc.cell(row=13, column=15).alignment = align_right
    ws_calc.cell(row=13, column=15).border = cell_border

    # Rec. Assinaturas Mobile Líquida Google Play (85%)
    ws_calc.cell(row=14, column=2, value="Receita Assinaturas Mobile Líquida (85%)").font = font_tbl_row
    for m_idx in range(3, 15):
        col_let = get_column_letter(m_idx)
        c = ws_calc.cell(row=14, column=m_idx, value=f"={col_let}8 * 'Premissas & Controle'!$C$26 * (1 - 'Premissas & Controle'!$C$27)")
        c.number_format = fmt_currency_usd
        c.alignment = align_right
        c.border = cell_border
    ws_calc.cell(row=14, column=15, value="=SUM(C14:N14)").number_format = fmt_currency_usd
    ws_calc.cell(row=14, column=15).font = font_tbl_bold
    ws_calc.cell(row=14, column=15).alignment = align_right
    ws_calc.cell(row=14, column=15).border = cell_border

    # Rec. Copilot Windows Desktop (Tíquete Médio Ponderado dos 6 Países: Sheet1!C35)
    ws_calc.cell(row=15, column=2, value="Receita Copilot Windows Desktop (Assinaturas)").font = font_tbl_bold
    for m_idx in range(3, 15):
        col_let = get_column_letter(m_idx)
        c = ws_calc.cell(row=15, column=m_idx, value=f"={col_let}10 * 'Premissas & Controle'!$C$35")
        c.number_format = fmt_currency_usd
        c.font = font_tbl_bold
        c.alignment = align_right
        c.border = cell_border
    ws_calc.cell(row=15, column=15, value="=SUM(C15:N15)").number_format = fmt_currency_usd
    ws_calc.cell(row=15, column=15).font = font_tbl_bold
    ws_calc.cell(row=15, column=15).alignment = align_right
    ws_calc.cell(row=15, column=15).border = cell_border

    # Rec. Copilot Windows Desktop Free (Monetização / Sponsored)
    ws_calc.cell(row=16, column=2, value="Receita Copilot Desktop Free (Parcerias / Ads)").font = font_tbl_row
    for m_idx in range(3, 15):
        col_let = get_column_letter(m_idx)
        c = ws_calc.cell(row=16, column=m_idx, value=f"={col_let}9 * 'Premissas & Controle'!$C$39")
        c.number_format = fmt_currency_usd
        c.alignment = align_right
        c.border = cell_border
    ws_calc.cell(row=16, column=15, value="=SUM(C16:N16)").number_format = fmt_currency_usd
    ws_calc.cell(row=16, column=15).font = font_tbl_bold
    ws_calc.cell(row=16, column=15).alignment = align_right
    ws_calc.cell(row=16, column=15).border = cell_border

    # Rec. Extensão Chrome Light
    ws_calc.cell(row=17, column=2, value="Receita Extensão Chrome (Ads + Assinaturas)").font = font_tbl_row
    for m_idx in range(3, 15):
        col_let = get_column_letter(m_idx)
        c = ws_calc.cell(row=17, column=m_idx, value=f"={col_let}11 * (0.60*'Premissas & Controle'!$C$40 + 0.40*'Premissas & Controle'!$C$41) + ({col_let}11*26)*'Premissas & Controle'!$C$42")
        c.number_format = fmt_currency_usd
        c.alignment = align_right
        c.border = cell_border
    ws_calc.cell(row=17, column=15, value="=SUM(C17:N17)").number_format = fmt_currency_usd
    ws_calc.cell(row=17, column=15).font = font_tbl_bold
    ws_calc.cell(row=17, column=15).alignment = align_right
    ws_calc.cell(row=17, column=15).border = cell_border

    # TOTAL RECEITA BRUTA CONSOLIDADA
    ws_calc.cell(row=18, column=2, value="TOTAL RECEITA BRUTA/LÍQUIDA CONSOLIDADA ($)").font = font_tbl_bold
    for m_idx in range(3, 16):
        col_let = get_column_letter(m_idx)
        c = ws_calc.cell(row=18, column=m_idx, value=f"=SUM({col_let}13:{col_let}17)")
        c.number_format = fmt_currency_usd
        c.font = font_tbl_bold
        c.fill = fill_total
        c.alignment = align_right
        c.border = total_border

    # 3. Custos Operacionais
    add_sec_header_calc(19, "3. CUSTOS OPERACIONAIS (MÍDIA PAGA PONDERADA, RAILWAY & CREWAI)")
    
    # Mídia Google Ads Mobile: Apps * 500 * CPI_Blended_Sheet1!J22
    ws_calc.cell(row=20, column=2, value="Mídia Google Ads Mobile (CPI Blended 6 Países)").font = font_tbl_row
    for m_idx in range(3, 15):
        col_let = get_column_letter(m_idx)
        c = ws_calc.cell(row=20, column=m_idx, value=f"={col_let}6 * 'Premissas & Controle'!$C$28 * 'Premissas & Controle'!$J$22")
        c.number_format = fmt_currency_usd
        c.alignment = align_right
        c.border = cell_border
    ws_calc.cell(row=20, column=15, value="=SUM(C20:N20)").number_format = fmt_currency_usd
    ws_calc.cell(row=20, column=15).font = font_tbl_bold
    ws_calc.cell(row=20, column=15).alignment = align_right
    ws_calc.cell(row=20, column=15).border = cell_border

    # Mídia Comercial Desktop
    ws_calc.cell(row=21, column=2, value="Mídia Comercial Desktop (LinkedIn, Google & Meta)").font = font_tbl_bold
    media_desktop = [75, 200, 450, 700, 1000, 2100, 3000, 3700, 4300, 4700, 5000, 5500]
    for m_idx, spend in enumerate(media_desktop, start=3):
        c = ws_calc.cell(row=21, column=m_idx, value=spend)
        c.font = font_tbl_bold
        c.number_format = fmt_currency_usd
        c.alignment = align_right
        c.border = cell_border
        c.fill = fill_input
    ws_calc.cell(row=21, column=15, value="=SUM(C21:N21)").number_format = fmt_currency_usd
    ws_calc.cell(row=21, column=15).font = font_tbl_bold
    ws_calc.cell(row=21, column=15).alignment = align_right
    ws_calc.cell(row=21, column=15).border = cell_border

    # Custo IA DeepSeek Flash V4
    ws_calc.cell(row=22, column=2, value="Custo IA DeepSeek Flash V4 (CrewAI Agentes + Mobile)").font = font_tbl_row
    for m_idx in range(3, 15):
        col_let = get_column_letter(m_idx)
        # Mobile: 0.012/usuário; Desktop Pro: 150 tarefas CrewAI completas (600 chamadas) * C37; Desktop Free: C38
        c = ws_calc.cell(row=22, column=m_idx, value=f"={col_let}7*0.012 + {col_let}10*150*'Premissas & Controle'!$C$37 + {col_let}9*'Premissas & Controle'!$C$38")
        c.number_format = fmt_currency_usd
        c.alignment = align_right
        c.border = cell_border
    ws_calc.cell(row=22, column=15, value="=SUM(C22:N22)").number_format = fmt_currency_usd
    ws_calc.cell(row=22, column=15).font = font_tbl_bold
    ws_calc.cell(row=22, column=15).alignment = align_right
    ws_calc.cell(row=22, column=15).border = cell_border

    # Backend Railway
    ws_calc.cell(row=23, column=2, value="Backend Railway (Containers Docker CrewAI + APIs)").font = font_tbl_bold
    railway_costs = [20, 30, 45, 60, 80, 105, 130, 155, 175, 195, 215, 230]
    for m_idx, r_cost in enumerate(railway_costs, start=3):
        c = ws_calc.cell(row=23, column=m_idx, value=r_cost)
        c.font = font_tbl_bold
        c.number_format = fmt_currency_usd
        c.alignment = align_right
        c.border = cell_border
        c.fill = fill_input
    ws_calc.cell(row=23, column=15, value="=SUM(C23:N23)").number_format = fmt_currency_usd
    ws_calc.cell(row=23, column=15).font = font_tbl_bold
    ws_calc.cell(row=23, column=15).alignment = align_right
    ws_calc.cell(row=23, column=15).border = cell_border

    # Taxas Gateways
    ws_calc.cell(row=24, column=2, value="Taxas Gateways de Pagamento (Stripe/Paddle 4%)").font = font_tbl_row
    for m_idx in range(3, 15):
        col_let = get_column_letter(m_idx)
        c = ws_calc.cell(row=24, column=m_idx, value=f"=({col_let}15 + {col_let}17) * 'Premissas & Controle'!$C$36")
        c.number_format = fmt_currency_usd
        c.alignment = align_right
        c.border = cell_border
    ws_calc.cell(row=24, column=15, value="=SUM(C24:N24)").number_format = fmt_currency_usd
    ws_calc.cell(row=24, column=15).font = font_tbl_bold
    ws_calc.cell(row=24, column=15).alignment = align_right
    ws_calc.cell(row=24, column=15).border = cell_border

    # TOTAL CUSTOS OPERACIONAIS
    ws_calc.cell(row=25, column=2, value="TOTAL CUSTOS OPERACIONAIS ($)").font = font_tbl_bold
    for m_idx in range(3, 16):
        col_let = get_column_letter(m_idx)
        c = ws_calc.cell(row=25, column=m_idx, value=f"=SUM({col_let}20:{col_let}24)")
        c.number_format = fmt_currency_usd
        c.font = font_tbl_bold
        c.fill = fill_total
        c.alignment = align_right
        c.border = total_border

    # 4. Resultados & Lucro
    add_sec_header_calc(26, "4. DEMONSTRATIVO DE RESULTADOS & LUCRO LÍQUIDO")
    
    ws_calc.cell(row=27, column=2, value="LUCRO LÍQUIDO MENSAL (USD $)").font = font_tbl_bold
    for m_idx in range(3, 16):
        col_let = get_column_letter(m_idx)
        c = ws_calc.cell(row=27, column=m_idx, value=f"={col_let}18 - {col_let}25")
        c.number_format = fmt_currency_usd
        c.font = font_highlight_green
        c.fill = fill_accent_green
        c.alignment = align_right
        c.border = total_border

    ws_calc.cell(row=28, column=2, value="Margem Líquida (%)").font = font_tbl_row
    for m_idx in range(3, 16):
        col_let = get_column_letter(m_idx)
        c = ws_calc.cell(row=28, column=m_idx, value=f"={col_let}27 / {col_let}18")
        c.number_format = fmt_percent
        c.alignment = align_right
        c.border = cell_border

    ws_calc.cell(row=29, column=2, value="Lucro Líquido Acumulado (USD $)").font = font_tbl_bold
    ws_calc.cell(row=29, column=3, value="=C27").number_format = fmt_currency_usd
    ws_calc.cell(row=29, column=3).alignment = align_right
    ws_calc.cell(row=29, column=3).border = cell_border
    for m_idx in range(4, 15):
        col_let = get_column_letter(m_idx)
        prev_let = get_column_letter(m_idx - 1)
        c = ws_calc.cell(row=29, column=m_idx, value=f"={prev_let}29 + {col_let}27")
        c.number_format = fmt_currency_usd
        c.alignment = align_right
        c.border = cell_border
    ws_calc.cell(row=29, column=15, value="=N29").number_format = fmt_currency_usd
    ws_calc.cell(row=29, column=15).font = font_tbl_bold
    ws_calc.cell(row=29, column=15).alignment = align_right
    ws_calc.cell(row=29, column=15).border = cell_border

    # 5. Conversão Multi-Moeda
    add_sec_header_calc(30, "5. CONVERSÃO MULTI-MOEDA (REAIS BRL & RÚPIAS INDIANAS INR)")
    
    ws_calc.cell(row=31, column=2, value="LUCRO LÍQUIDO MENSAL EM REAIS (BRL - R$)").font = font_section
    for m_idx in range(3, 16):
        col_let = get_column_letter(m_idx)
        c = ws_calc.cell(row=31, column=m_idx, value=f"={col_let}27 * 'Premissas & Controle'!$C$6")
        c.number_format = fmt_currency_brl
        c.font = font_highlight_green
        c.fill = fill_accent_green
        c.alignment = align_right
        c.border = total_border

    ws_calc.cell(row=32, column=2, value="LUCRO LÍQUIDO ACUMULADO EM REAIS (BRL - R$)").font = font_tbl_bold
    ws_calc.cell(row=32, column=3, value="=C31").number_format = fmt_currency_brl
    ws_calc.cell(row=32, column=3).alignment = align_right
    ws_calc.cell(row=32, column=3).border = cell_border
    for m_idx in range(4, 15):
        col_let = get_column_letter(m_idx)
        prev_let = get_column_letter(m_idx - 1)
        c = ws_calc.cell(row=32, column=m_idx, value=f"={prev_let}32 + {col_let}31")
        c.number_format = fmt_currency_brl
        c.alignment = align_right
        c.border = cell_border
    ws_calc.cell(row=32, column=15, value="=N32").number_format = fmt_currency_brl
    ws_calc.cell(row=32, column=15).font = font_section
    ws_calc.cell(row=32, column=15).alignment = align_right
    ws_calc.cell(row=32, column=15).border = total_border

    ws_calc.cell(row=33, column=2, value="LUCRO LÍQUIDO MENSAL EM RÚPIAS (INR - ₹)").font = font_tbl_row
    for m_idx in range(3, 16):
        col_let = get_column_letter(m_idx)
        c = ws_calc.cell(row=33, column=m_idx, value=f"={col_let}27 * 'Premissas & Controle'!$C$7")
        c.number_format = fmt_currency_inr
        c.alignment = align_right
        c.border = cell_border

    ws_calc.column_dimensions["A"].width = 3
    ws_calc.column_dimensions["B"].width = 46
    for m_idx in range(3, 16):
        col_let = get_column_letter(m_idx)
        ws_calc.column_dimensions[col_let].width = 16

    # =============================================================
    # SHEET 4: COMPARATIVO DE CENÁRIOS (100% DINÂMICO)
    # =============================================================
    ws_scen = wb.create_sheet(title="Comparativo de Cenários")
    ws_scen.views.sheetView[0].showGridLines = True
    
    ws_scen.merge_cells("B2:F2")
    ws_scen["B2"] = "COMPARATIVO EXECUTIVO DE CENÁRIOS NO M12 (MATRIZ GLOBAL 6 PAÍSES)"
    ws_scen["B2"].font = font_title
    ws_scen["B2"].fill = fill_header_navy
    ws_scen["B2"].alignment = align_center
    ws_scen.row_dimensions[2].height = 34

    ws_scen.merge_cells("B3:F3")
    ws_scen["B3"] = "Todos os faturamentos e lucros recalculam dinamicamente a partir dos assinantes e parâmetros de Premissas."
    ws_scen["B3"].font = font_subtitle
    ws_scen["B3"].fill = fill_header_navy
    ws_scen["B3"].alignment = align_center
    ws_scen.row_dimensions[3].height = 20

    scen_headers = ["Indicador Estratégico no Mês 12", "Cenário Conservador", "Cenário Realista (P50)", "Cenário Agressivo", "Fórmula / Lógica"]
    ws_scen.row_dimensions[5].height = 25
    for j, h in enumerate(scen_headers, start=2):
        c = ws_scen.cell(row=5, column=j, value=h)
        c.font = font_tbl_header
        c.fill = fill_header_slate
        c.alignment = align_center if j in [3, 4, 5] else align_left
        c.border = header_border

    scen_inputs = [
        (6, "Assinantes Copilot Windows Pagantes (M12)", 1200, 1600, 4500, fmt_int, "Variável de escala de assinantes desktop"),
        (7, "Usuários Ativos Copilot Desktop - PLANO FREE (M12)", 5000, 8000, 22000, fmt_int, "Base gratuita gerando conversão e receita de ads"),
        (8, "Usuários Ativos Mobile MAU (M12)", 10000, 12500, 31500, fmt_int, "Base ativa da suíte de 6 apps móveis"),
        (9, "Assinantes Mobile Pagantes ($9/mês) (M12)", 100, 125, 315, fmt_int, "Assinantes mobile no Google Play"),
        (10, "Assinantes Extensão Chrome Light (M12)", 180, 250, 750, fmt_int, "Assinantes do assistente de código no Chrome"),
        (11, "Investimento Mídia Mensal no M12 ($ USD)", 4200, 5960, 11375, fmt_currency_usd, "Investimento em Google, LinkedIn e Meta Ads"),
    ]

    for r_idx, label, c_val, r_val, a_val, num_fmt, desc in scen_inputs:
        ws_scen.cell(row=r_idx, column=2, value=label).font = font_tbl_bold
        ws_scen.cell(row=r_idx, column=2).border = cell_border
        
        for c_idx, val in enumerate([c_val, r_val, a_val], start=3):
            cell = ws_scen.cell(row=r_idx, column=c_idx, value=val)
            cell.font = font_tbl_bold
            cell.number_format = num_fmt
            cell.alignment = align_right
            cell.border = cell_border
            cell.fill = fill_input
        
        ws_scen.cell(row=r_idx, column=6, value=desc).font = font_note

    calc_rows = [
        (13, "FATURAMENTO BRUTO MENSAL M12 (USD $)", 
         "=C6*'Premissas & Controle'!$C$35 + C7*'Premissas & Controle'!$C$39 + (C8-C9)*'Premissas & Controle'!$I$22 + C9*'Premissas & Controle'!$C$26*(1-'Premissas & Controle'!$C$27) + C10*(0.6*'Premissas & Controle'!$C$40 + 0.4*'Premissas & Controle'!$C$41)",
         "=D6*'Premissas & Controle'!$C$35 + D7*'Premissas & Controle'!$C$39 + (D8-D9)*'Premissas & Controle'!$I$22 + D9*'Premissas & Controle'!$C$26*(1-'Premissas & Controle'!$C$27) + D10*(0.6*'Premissas & Controle'!$C$40 + 0.4*'Premissas & Controle'!$C$41)",
         "=E6*'Premissas & Controle'!$C$35 + E7*'Premissas & Controle'!$C$39 + (E8-E9)*'Premissas & Controle'!$I$22 + E9*'Premissas & Controle'!$C$26*(1-'Premissas & Controle'!$C$27) + E10*(0.6*'Premissas & Controle'!$C$40 + 0.4*'Premissas & Controle'!$C$41)",
         fmt_currency_usd, "Fórmula dinâmica considerando ARPU blended dos 6 países"),
        
        (14, "FATURAMENTO MENSAL M12 EM REAIS (BRL - R$)",
         "=C13 * 'Premissas & Controle'!$C$6",
         "=D13 * 'Premissas & Controle'!$C$6",
         "=E13 * 'Premissas & Controle'!$C$6",
         fmt_currency_brl, "Fórmula: Faturamento USD * Câmbio USD/BRL"),

        (15, "FATURAMENTO MENSAL M12 EM RÚPIAS (INR - ₹)",
         "=C13 * 'Premissas & Controle'!$C$7",
         "=D13 * 'Premissas & Controle'!$C$7",
         "=E13 * 'Premissas & Controle'!$C$7",
         fmt_currency_inr, "Fórmula: Faturamento USD * Câmbio USD/INR"),

        (16, "Custos Totais no Mês 12 ($ USD)",
         "=C11 + (C8*0.018 + C6*700*'Premissas & Controle'!$C$37 + C7*'Premissas & Controle'!$C$38) + 180 + C13*0.035",
         "=D11 + (D8*0.018 + D6*700*'Premissas & Controle'!$C$37 + D7*'Premissas & Controle'!$C$38) + 230 + D13*0.035",
         "=E11 + (E8*0.018 + E6*700*'Premissas & Controle'!$C$37 + E7*'Premissas & Controle'!$C$38) + 450 + E13*0.035",
         fmt_currency_usd, "Fórmula: Mídia + IA DeepSeek Flash V4 + Railway Containers + Gateways"),

        (17, "LUCRO LÍQUIDO MENSAL NO MÊS 12 (USD $)",
         "=C13 - C16",
         "=D13 - D16",
         "=E13 - E16",
         fmt_currency_usd, "Fórmula: Faturamento Bruto - Custos Totais"),

        (18, "LUCRO LÍQUIDO MENSAL NO M12 (BRL - R$)",
         "=C17 * 'Premissas & Controle'!$C$6",
         "=D17 * 'Premissas & Controle'!$C$6",
         "=E17 * 'Premissas & Controle'!$C$6",
         fmt_currency_brl, "Fórmula: Lucro USD * Câmbio USD/BRL"),

        (19, "LUCRO LÍQUIDO MENSAL NO M12 (INR - ₹)",
         "=C17 * 'Premissas & Controle'!$C$7",
         "=D17 * 'Premissas & Controle'!$C$7",
         "=E17 * 'Premissas & Controle'!$C$7",
         fmt_currency_inr, "Fórmula: Lucro USD * Câmbio USD/INR"),

        (20, "Margem Líquida no Mês 12 (%)",
         "=C17 / C13",
         "=D17 / D13",
         "=E17 / E13",
         fmt_percent, "Fórmula: Lucro Líquido / Faturamento Bruto"),

        (21, "LUCRO LÍQUIDO ESTIMADO ACUMULADO ANO 1 (BRL)",
         "=C18 * 5.2",
         "='Calculadora 12 Meses'!O32",
         "=E18 * 5.4",
         fmt_currency_brl, "Fórmula dinâmica: Multiplicador da curva de ramp-up"),
    ]

    for r_idx, label, c_form, r_form, a_form, num_fmt, desc in calc_rows:
        is_profit = "LUCRO" in label or "FATURAMENTO" in label
        ws_scen.cell(row=r_idx, column=2, value=label).font = font_section if is_profit else font_tbl_row
        ws_scen.cell(row=r_idx, column=2).border = cell_border
        
        for c_idx, form in enumerate([c_form, r_form, a_form], start=3):
            cell = ws_scen.cell(row=r_idx, column=c_idx, value=form)
            cell.font = font_highlight_green if "LUCRO" in label else font_tbl_bold
            cell.number_format = num_fmt
            cell.alignment = align_right
            cell.border = total_border if is_profit else cell_border
            if "LUCRO" in label:
                cell.fill = fill_accent_green
        
        ws_scen.cell(row=r_idx, column=6, value=desc).font = font_note

    ws_scen.column_dimensions["A"].width = 3
    ws_scen.column_dimensions["B"].width = 46
    ws_scen.column_dimensions["C"].width = 24
    ws_scen.column_dimensions["D"].width = 24
    ws_scen.column_dimensions["E"].width = 24
    ws_scen.column_dimensions["F"].width = 50

    try:
        wb.save(output_path)
        print(f"Spreadsheet calculator updated successfully at: {output_path}")
    except PermissionError:
        alt_path = output_path.replace(".xlsx", "_v4.xlsx").replace(".xls", "_v4.xls")
        wb.save(alt_path)
        print(f"Warning: File was locked. Saved to: {alt_path}")

if __name__ == "__main__":
    import sys
    out = sys.argv[1] if len(sys.argv) > 1 else "Calculadora_Financeira_SAP_AI_v4.xlsx"
    build_calculator(out)
