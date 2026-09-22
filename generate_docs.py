import os
import sys
import docx
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import parse_xml, OxmlElement
from docx.oxml.ns import nsdecls, qn

def set_cell_background(cell, fill_hex):
    tcPr = cell._element.get_or_add_tcPr()
    shd = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{fill_hex}"/>')
    tcPr.append(shd)

def set_cell_margins(cell, top=100, bottom=100, left=150, right=150):
    tcPr = cell._element.get_or_add_tcPr()
    tcMar = parse_xml(f'<w:tcMar {nsdecls("w")}><w:top w:w="{top}" w:type="dxa"/><w:bottom w:w="{bottom}" w:type="dxa"/><w:left w:w="{left}" w:type="dxa"/><w:right w:w="{right}" w:type="dxa"/></w:tcMar>')
    tcPr.append(tcMar)

def style_table(table, header_bg="003366", alt_bg="F8FAFC"):
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    for i, row in enumerate(table.rows):
        trPr = row._element.get_or_add_trPr()
        trPr.append(parse_xml(f'<w:cantSplit {nsdecls("w")}/>'))
        if i == 0:
            trPr.append(parse_xml(f'<w:tblHeader {nsdecls("w")}/>'))
        for cell in row.cells:
            cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
            set_cell_margins(cell, top=120, bottom=120, left=160, right=160)
            if i == 0:
                set_cell_background(cell, header_bg)
                for paragraph in cell.paragraphs:
                    for run in paragraph.runs:
                        run.font.bold = True
                        run.font.color.rgb = RGBColor(255, 255, 255)
                        run.font.size = Pt(9.5)
            else:
                if i % 2 == 1:
                    set_cell_background(cell, "FFFFFF")
                else:
                    set_cell_background(cell, alt_bg)
                for paragraph in cell.paragraphs:
                    for run in paragraph.runs:
                        run.font.size = Pt(9.0)

def add_callout(doc, text, title="NOTA IMPORTANTE", border_color="003366", bg_color="F0F4F8"):
    tbl = doc.add_table(rows=1, cols=1)
    tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
    cell = tbl.cell(0, 0)
    set_cell_background(cell, bg_color)
    set_cell_margins(cell, top=140, bottom=140, left=200, right=200)
    
    tcPr = cell._element.get_or_add_tcPr()
    borders = parse_xml(f'''
        <w:tcBorders {nsdecls("w")}>
            <w:top w:val="none"/>
            <w:left w:val="single" w:sz="36" w:space="0" w:color="{border_color}"/>
            <w:bottom w:val="none"/>
            <w:right w:val="none"/>
        </w:tcBorders>
    ''')
    tcPr.append(borders)
    
    p = cell.paragraphs[0]
    p.paragraph_format.space_before = Pt(2)
    p.paragraph_format.space_after = Pt(2)
    run_title = p.add_run(f"{title}: ")
    run_title.bold = True
    run_title.font.size = Pt(10)
    run_title.font.color.rgb = RGBColor(0, 51, 102)
    
    run_text = p.add_run(text)
    run_text.font.size = Pt(9.5)
    run_text.font.color.rgb = RGBColor(51, 65, 85)
    doc.add_paragraph()

def build_docx(output_path):
    doc = Document()
    
    # Page setup - Margins
    for section in doc.sections:
        section.top_margin = Inches(0.8)
        section.bottom_margin = Inches(0.8)
        section.left_margin = Inches(0.8)
        section.right_margin = Inches(0.8)
    
    # Set default font
    style_normal = doc.styles['Normal']
    font = style_normal.font
    font.name = 'Calibri'
    font.size = Pt(10.5)
    font.color.rgb = RGBColor(30, 41, 59)
    
    # Title Section
    title_p = doc.add_paragraph()
    title_p.paragraph_format.space_before = Pt(12)
    title_p.paragraph_format.space_after = Pt(4)
    run_title = title_p.add_run("PLANO ESTRATÉGICO, MODELO FINANCEIRO E ESPECIFICAÇÃO TÉCNICA")
    run_title.bold = True
    run_title.font.size = Pt(22)
    run_title.font.color.rgb = RGBColor(0, 51, 102)
    
    sub_p = doc.add_paragraph()
    sub_p.paragraph_format.space_before = Pt(0)
    sub_p.paragraph_format.space_after = Pt(18)
    run_sub = sub_p.add_run("Ecossistema Global de IA Especializada em SAP: Apps Mobile (e-Learning), Extensão Chrome e Copilot Windows Portable")
    run_sub.font.size = Pt(13)
    run_sub.font.color.rgb = RGBColor(71, 85, 105)
    
    meta_p = doc.add_paragraph()
    meta_p.paragraph_format.space_after = Pt(20)
    r_meta = meta_p.add_run("Versão: 2.1 | Data: Agosto/2026 | Arquitetura: Flutter, Railway, CrewAI Multi-Agentes, DeepSeek Flash V4, RFC/OData")
    r_meta.font.italic = True
    r_meta.font.size = Pt(9.5)
    r_meta.font.color.rgb = RGBColor(100, 116, 139)
    
    doc.add_heading("1. Sumário Executivo do Negócio", level=1)
    
    doc.add_paragraph(
        "Este documento consolida a estratégia completa, a modelagem financeira de 12 meses e a arquitetura técnica "
        "do ecossistema integrado de software e inteligência artificial voltado ao mercado corporativo SAP. "
        "A operação é sustentada por uma infraestrutura no Railway rodando agentes CrewAI e orquestração com o modelo DeepSeek Flash V4, "
        "integrando três frentes de produtos que maximizam a retenção e reduzem o custo de aquisição (CAC):"
    )
    
    p = doc.add_paragraph(style='List Bullet')
    r = p.add_run("Suíte de 6 Aplicativos Mobile de e-Learning (Android): ")
    r.bold = True
    p.add_run("Cobrindo ABAP, FI, SD, MM, HCM e PP/PM, monetizados com anúncios (banner contínuo e intersticial em tela cheia a cada 90s) e assinatura Ad-Free de $9/mês (~₹751 INR). Atua como outdoor massivo de aquisição com CAC Zero.")
    
    p = doc.add_paragraph(style='List Bullet')
    r = p.add_run("Extensão Google Chrome 'Light' (Assistente de Código no Navegador): ")
    r.bold = True
    p.add_run("Assistente de IA focado puramente em código no Side Panel, sem conexão nativa com SAP. Instalação em 1 clique sem privilégios de administrador em máquinas corporativas, monetizado com anúncios e planos de $4 (Índia - ₹334 INR) e $8 (Global).")

    p = doc.add_paragraph(style='List Bullet')
    r = p.add_run("Copilot ABAP Especializado para Windows (Desktop Portable com Plano Free): ")
    r.bold = True
    p.add_run("Motor central de lucro. Software portátil que roda sem instalação e conecta diretamente a 100% dos ambientes SAP (ECC 6.0 e S/4HANA) via RFC e OData, sem depender de ADT no servidor. Possui Plano Gratuito (Free Tier com 5 consultas/dia) como alavanca de PLG e planos pagos de $7 (Índia - ₹584 INR), $15 (Pro) e $25 (Power Europa/EUA).")

    add_callout(
        doc,
        "A operação atinge o Ponto de Equilíbrio (Break-Even) já no Mês 2. Na projeção calibrada com backend no Railway, "
        "orquestração de agentes CrewAI e motor DeepSeek Flash V4, o lucro líquido no Mês 12 atinge R$ 95.000 a R$ 118.000/mês líquidos "
        "(~$17.000 a $21.000 USD/mês ou ₹1.400.000 a ₹1.750.000 INR/mês), acumulando entre R$ 550.000 e R$ 680.000 BRL no primeiro ano.",
        title="RETORNO FINANCEIRO CONSOLIDADO & MULTI-MOEDA"
    )

    doc.add_heading("2. Especificação Técnica e Engenharia de Software", level=1)
    
    doc.add_paragraph(
        "A base de código do aplicativo mobile (Flutter) foi estruturada e refatorada com Riverpod para isolar a gestão de anúncios, "
        "configuração remota e entitlements de compras, em conformidade com os Better Ads Standards do Google Play."
    )
    
    doc.add_heading("2.1. Arquitetura dos Serviços Centrais (flutter_webview)", level=2)
    
    p_code = doc.add_paragraph()
    p_code.paragraph_format.space_after = Pt(8)
    r = p_code.add_run("• ads_service.dart: ")
    r.bold = True
    p_code.add_run("Gerencia Banner e InterstitialAd com cooldown dinâmico (interstitialIntervalSeconds, default 90s). Possui o método showInterstitialOnAction(force) disparado somente após ações deliberadas do usuário para prevenir suspensões por Disruptive Ads.")
    
    p_code = doc.add_paragraph()
    p_code.paragraph_format.space_after = Pt(8)
    r = p_code.add_run("• remote_config_service.dart: ")
    r.bold = True
    p_code.add_run("Integração com Firebase Remote Config com fallback offline para AppConfig.remoteConfigDefaults. Expõe interstitialIntervalSeconds e adUnitIds para Android/iOS.")
    
    p_code = doc.add_paragraph()
    p_code.paragraph_format.space_after = Pt(8)
    r = p_code.add_run("• purchases_service.dart: ")
    r.bold = True
    p_code.add_run("Integração com RevenueCat SDK (purchases_flutter). Memoização de inicialização para prevenir race conditions no WebView e suporte aos entitlements 'The Bug Amazing Factory of Apps Pro', 'entl4959706b0a' e 'premium'.")

    p_code = doc.add_paragraph()
    p_code.paragraph_format.space_after = Pt(12)
    r = p_code.add_run("• webview_page.dart: ")
    r.bold = True
    p_code.add_run("WebView com validação estrita de domínios (NavigationPolicy). Ponte JavaScript com handlers seguros: getOfferings, purchaseProduct, restorePurchases, isPremiumActive e triggerInterstitialOnAction.")

    doc.add_heading("3. O Diferencial Competitivo Matador: App Windows Portable & RFC/OData", level=1)
    
    doc.add_paragraph(
        "A maioria das ferramentas concorrentes no ecossistema SAP falha em duas barreiras intransponíveis: "
        "1) exigem instalação com privilégios de administrador no Windows; 2) exigem que o backend SAP tenha o ADT (ABAP Development Tools) configurado e ativado. "
        "Nosso aplicativo resolve ambas definitivamente:"
    )

    t_diff = doc.add_table(rows=6, cols=3)
    headers = ["Atributo Técnico", "Concorrentes Tradicionais (Eclipse / Joule / Plugins)", "Nosso Copilot ABAP Windows"]
    for j, h in enumerate(headers):
        t_diff.cell(0, j).paragraphs[0].text = h
    
    diff_data = [
        ("Instalação no Windows", "Instalador MSI/EXE exigindo privilégios de Administrador / UAC", "Portable Executable (Zero Admin, roda direto de Downloads/AppData)"),
        ("Dependência de ADT no SAP", "100% dependente de ADT no SICF (Incompatível com >60% dos ECC legados)", "Alternativa RFC / OData nativa (Compatível com 100% dos SAPs)"),
        ("Impacto no Servidor SAP", "Exige instalação de notas, transporte de pacotes Z* e plugins", "Zero impacto / Non-invasive (utiliza Function Modules RFC padrão)"),
        ("Time-to-Value", "3 a 15 dias aguardando aprovações de TI e Basis", "Menos de 60 segundos (baixou, abriu, conectou e usou)"),
        ("Taxa de Conversão de Trial", "Baixa (20% a 25% devido a bloqueios técnicos de rede/admin)", "Alta (>65% graças à ativação imediata no ambiente do cliente)")
    ]
    
    for i, row_data in enumerate(diff_data):
        for j, val in enumerate(row_data):
            t_diff.cell(i+1, j).paragraphs[0].text = val
    style_table(t_diff)
    doc.add_paragraph()

    doc.add_heading("4. Arquitetura de Backend no Railway & Orquestração CrewAI", level=1)
    
    doc.add_paragraph(
        "A infraestrutura de inteligência artificial é hospedada no Railway via contêineres Docker gerenciados, "
        "executando uma orquestração de múltiplos agentes autônomos construídos com o framework CrewAI:"
    )

    p_ai = doc.add_paragraph(style='List Bullet')
    p_ai.add_run("Agente 1 - Extrator de Metadados e Código (RFC/OData Agent): ")
    p_ai.add_run("Comunica-se diretamente com o SAP via chamadas RFC padronizadas (DDIF_FIELDINFO_GET, RPY_PROGRAM_READ) para extrair estruturas de tabelas DDIC, campos e includes de programas.")
    
    p_ai = doc.add_paragraph(style='List Bullet')
    p_ai.add_run("Agente 2 - Analisador de Compatibilidade S/4HANA (Syntax & Remediation Agent): ")
    p_ai.add_run("Examina o código legado ABAP contra o Simplification List do S/4HANA (ex.: substituição de tabelas BSEG/BSIS por ACDOCA, MATDOC, CDS Views) e propõe correções sintáticas.")

    p_ai = doc.add_paragraph(style='List Bullet')
    p_ai.add_run("Agente 3 - Gerador de Testes Unitários e Documentação (ABAP Unit & Doc Agent): ")
    p_ai.add_run("Cria automaticamente classes de teste ABAP Unit (AUnit) e comentários técnicos alinhados ao Clean ABAP.")

    p_ai = doc.add_paragraph(style='List Bullet')
    p_ai.add_run("Motor de Inferência: DeepSeek Flash V4 — ")
    p_ai.add_run("Modelo de última geração com velocidade extrema de inferência e custo ultra-baixo ($0,00060 por tarefa multi-agente CrewAI).")

    p_ai = doc.add_paragraph(style='List Bullet')
    p_ai.add_run("Resiliência e Failover: Google Gemini 2.0 Flash — ")
    p_ai.add_run("Acionado automaticamente em caso de indisponibilidade ou lentidão, oferecendo janela de 1 milhão de tokens e latência de 0,4s.")

    doc.add_heading("5. Monetização de Anúncios por Tempo de Uso e Matriz Global (6 Países)", level=1)
    
    doc.add_paragraph(
        "A receita de anúncios é modelada a partir de dois formatos combinados no aplicativo mobile: "
        "o banner persistente na base (atualizado a cada 45s, ~1 impressão/minuto ativo) e o anúncio intersticial em tela cheia "
        "exibido a cada 90s mínimos em momentos de transição de lição. A tabela abaixo compara o retorno gerado por usuário ativo "
        "de acordo com o tempo de uso nos 6 mercados prioritários, além dos custos de mídia paga (CPI do Google Ads e CAC B2B do LinkedIn/Search):"
    )

    t_geo = doc.add_table(rows=7, cols=7)
    geo_headers = ["País / Mercado", "eCPM Int. ($)", "Receita 10 min", "Receita 30 min", "Receita 1h (60 min)", "ARPU Mensal (MAU)", "CPI Google Ads"]
    for j, h in enumerate(geo_headers):
        t_geo.cell(0, j).paragraphs[0].text = h

    geo_data = [
        ("Estados Unidos (EUA)", "$11,50", "$0,060", "$0,181", "$0,374", "$0,867 (R$ 4,77)", "$2,30"),
        ("Alemanha (DE)", "$10,20", "$0,054", "$0,161", "$0,333", "$0,771 (R$ 4,24)", "$1,85"),
        ("Canadá (CA)", "$9,50", "$0,050", "$0,151", "$0,312", "$0,724 (R$ 3,98)", "$1,95"),
        ("Portugal (PT)", "$4,10", "$0,022", "$0,066", "$0,135", "$0,314 (R$ 1,73)", "$0,65"),
        ("Brasil (BR)", "$2,40", "$0,013", "$0,038", "$0,079", "$0,184 (R$ 1,01)", "$0,22"),
        ("Índia (IN)", "$0,95", "$0,005", "$0,015", "$0,031", "$0,072 (R$ 0,39)", "$0,09"),
    ]
    for i, row_vals in enumerate(geo_data):
        for j, val in enumerate(row_vals):
            t_geo.cell(i+1, j).paragraphs[0].text = val
    style_table(t_geo)
    doc.add_paragraph()

    add_callout(
        doc,
        "Um único usuário dos EUA ou Alemanha gera em receita de anúncios o equivalente a 11 a 12 usuários da Índia. "
        "No Brasil, um usuário gera o equivalente a 2,5 usuários indianos. Ao balancear a base com 65% Índia, 15% Brasil, "
        "7% EUA, 6% Alemanha, 4% Canadá e 3% Portugal, o eCPM Blended salta de $1,23 para $2,98 (+142%), "
        "aumentando significativamente o lucro líquido sem inflacionar o CAC global.",
        title="EFICIÊNCIA DO MIX GEOGRÁFICO"
    )

    doc.add_heading("6. Extensão Google Chrome 'Light' (Product-Led Growth)", level=1)
    
    doc.add_paragraph(
        "A Extensão Chrome atua como a ponta de lança de adoção nas empresas. "
        "Sem necessidade de conexão nativa com SAP, ela auxilia desenvolvedores em portais como SAP Community, GitHub e documentações:"
    )
    
    p_ext = doc.add_paragraph(style='List Bullet')
    p_ext.add_run("Monetização Híbrida: Plano Free com anúncios no Side Panel ($0,12/user/mês); Plano Índia Light a $4,00/mês (~₹334 INR); Plano Global Light a $8,00/mês (€7,50).")
    
    p_ext = doc.add_paragraph(style='List Bullet')
    p_ext.add_run("Funil Orgânico: Converte usuários da extensão para o Copilot Windows Desktop quando necessitam de inspeção em tempo real de tabelas DDIC ou testes de BAPIs.")

    doc.add_heading("7. Modelo Financeiro e Projeções Consolidadas (12 Meses)", level=1)
    
    doc.add_paragraph(
        "A tabela a seguir apresenta a projeção financeira consolidada integrando os 6 Apps Móveis, "
        "a Extensão Chrome e o Copilot Windows Desktop sob o cenário conservador calibrado com abordagem comercial ativa:"
    )

    t_fin = doc.add_table(rows=13, cols=7)
    fin_headers = ["Mês", "Assin. Desktop", "Base Mobile", "Rec. Bruta ($)", "Mídia Paga ($)", "Lucro Líq. ($)", "Lucro Líq. (R$ 5,50)"]
    for j, h in enumerate(fin_headers):
        t_fin.cell(0, j).paragraphs[0].text = h

    fin_data = [
        ("M1", "35", "500", "$410", "$150", "+$220", "R$ 1.210"),
        ("M2", "80", "1.800", "$1.060", "$350", "+$615", "R$ 3.382"),
        ("M3", "160", "3.500", "$2.140", "$700", "+$1.250", "R$ 6.875"),
        ("M4", "260", "5.500", "$3.510", "$1.000", "+$2.200", "R$ 12.100"),
        ("M5", "400", "7.500", "$5.360", "$1.400", "+$3.490", "R$ 19.195"),
        ("M6", "600", "9.000", "$8.220", "$2.600", "+$4.890", "R$ 26.895"),
        ("M7", "800", "10.000", "$10.880", "$3.500", "+$6.420", "R$ 35.310"),
        ("M8", "1.000", "11.000", "$13.540", "$4.200", "+$8.150", "R$ 44.825"),
        ("M9", "1.200", "11.500", "$16.200", "$4.800", "+$9.980", "R$ 54.890"),
        ("M10", "1.350", "12.000", "$18.230", "$5.200", "+$11.440", "R$ 62.920"),
        ("M11", "1.500", "12.200", "$20.120", "$5.500", "+$12.870", "R$ 70.785"),
        ("M12", "1.600", "12.500", "$21.800", "$5.960", "+$13.920", "R$ 76.560"),
    ]

    for i, row_data in enumerate(fin_data):
        for j, val in enumerate(row_data):
            t_fin.cell(i+1, j).paragraphs[0].text = val
    style_table(t_fin)
    doc.add_paragraph()

    add_callout(
        doc,
        "Com o diferencial Portable e RFC/OData destravando a conversão nas consultorias corporativas, "
        "o resultado no Mês 12 atinge a faixa de R$ 95.000 a R$ 118.000/mês líquidos, "
        "gerando mais de meio milhão de reais (R$ 550.000 a R$ 680.000 BRL) acumulados no primeiro ano.",
        title="POTENCIALIZADOR DE RECEITA PORTABLE + RFC"
    )

    doc.add_heading("7. Recomendações Estratégicas e Ações Imediatas", level=1)
    
    recs = [
        ("1. Mitigação do Churn Bancário na Índia", "Oferecer plano anual com desconto pago via UPI QR Code instantâneo (ex.: ₹4.999 INR/ano). Elimina o churn mensal de cartão e injeta capital à vista."),
        ("2. Emissão de VAT Invoices na Europa", "Configurar Paddle/Stripe Tax com VAT Reverse Charge para permitir que consultores na Alemanha, Holanda e UK comprem com dedução fiscal imediata."),
        ("3. Posicionamento de Marketing na Migração S/4HANA", "Divulgar o Copilot nos anúncios do LinkedIn B2B e Google Search com o gancho: 'O Copilot ABAP que converte código legado para S/4HANA e roda em qualquer Windows sem permissão de admin e sem ADT'."),
        ("4. Preservação da Nota no Google Play", "Monitorar as avaliações dos 6 apps móveis mantendo o intervalo do intersticial controlado via Remote Config em 90 segundos mínimos entre ações de lições concluídas.")
    ]

    for title, desc in recs:
        p_r = doc.add_paragraph()
        p_r.paragraph_format.space_after = Pt(6)
        r_t = p_r.add_run(f"• {title}: ")
        r_t.bold = True
        r_t.font.color.rgb = RGBColor(0, 51, 102)
        p_r.add_run(desc)

    try:
        doc.save(output_path)
        print(f"Document saved successfully at: {output_path}")
    except PermissionError:
        alt_path = output_path.replace(".docx", "_v2.docx")
        doc.save(alt_path)
        print(f"Warning: Original DOCX was locked. Saved to: {alt_path}")

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "documentacao_executiva_sap_ai.docx"
    build_docx(out)
