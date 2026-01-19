const { Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell, 
        AlignmentType, BorderStyle, WidthType, ShadingType, PageBreak } = require('docx');
const fs = require('fs');

const c = {
    primaryBlue: "0066FF", deepBlue: "0A1628", glowBlue: "00A3FF",
    softBlue: "1A3A5C", iceBlue: "E0F4FF", glassBlue: "1E3A5F",
    accentCyan: "00D4FF", white: "FFFFFF", lightGray: "B8C5D9",
    success: "00FF7F", error: "FF3B30", gold: "FFD700"
};

function header(text) {
    return new Paragraph({
        spacing: { before: 400, after: 200 },
        shading: { fill: c.deepBlue, type: ShadingType.CLEAR },
        children: [new TextRun({ text, bold: true, italics: true, size: 36, font: "Arial", color: c.accentCyan })]
    });
}

function subHeader(text) {
    return new Paragraph({
        spacing: { before: 300, after: 150 },
        children: [new TextRun({ text, bold: true, size: 28, font: "Arial", color: c.glowBlue })]
    });
}

function body(text, color = c.deepBlue) {
    return new Paragraph({
        spacing: { after: 120 },
        children: [new TextRun({ text, bold: true, size: 22, font: "Arial", color })]
    });
}

function bullet(label, desc) {
    return new Paragraph({
        spacing: { after: 150 },
        children: [
            new TextRun({ text: "✦ ", bold: true, size: 24, color: c.accentCyan }),
            new TextRun({ text: label + ": ", bold: true, italics: true, size: 24, font: "Arial", color: c.glowBlue }),
            new TextRun({ text: desc, bold: true, size: 22, font: "Arial" })
        ]
    });
}

function code(lines) {
    return lines.map((line, i) => new Paragraph({
        shading: { fill: c.deepBlue, type: ShadingType.CLEAR },
        spacing: { before: i === 0 ? 100 : 0, after: i === lines.length - 1 ? 100 : 0 },
        children: [new TextRun({ text: line, bold: true, size: 18, font: "Courier New", color: c.white })]
    }));
}

function table(headers, rows) {
    const border = { style: BorderStyle.SINGLE, size: 1, color: c.glowBlue };
    const borders = { top: border, bottom: border, left: border, right: border };
    const colWidth = Math.floor(9360 / headers.length);
    
    return new Table({
        width: { size: 100, type: WidthType.PERCENTAGE },
        columnWidths: headers.map(() => colWidth),
        rows: [
            new TableRow({
                children: headers.map(h => new TableCell({
                    width: { size: colWidth, type: WidthType.DXA },
                    shading: { fill: c.deepBlue, type: ShadingType.CLEAR },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    borders,
                    children: [new Paragraph({ 
                        alignment: AlignmentType.CENTER,
                        children: [new TextRun({ text: h, bold: true, italics: true, size: 20, color: c.white })] 
                    })]
                }))
            }),
            ...rows.map((row, ri) => new TableRow({
                children: row.map((cell, ci) => new TableCell({
                    width: { size: colWidth, type: WidthType.DXA },
                    shading: { fill: ri % 2 === 0 ? c.iceBlue : c.white, type: ShadingType.CLEAR },
                    margins: { top: 60, bottom: 60, left: 120, right: 120 },
                    borders,
                    children: [new Paragraph({ 
                        alignment: ci === 0 ? AlignmentType.LEFT : AlignmentType.CENTER,
                        children: [new TextRun({ text: cell, bold: true, size: 18, color: c.deepBlue })] 
                    })]
                }))
            }))
        ]
    });
}

const doc = new Document({
    sections: [{
        properties: {
            page: {
                size: { width: 12240, height: 15840 },
                margin: { top: 1080, right: 1080, bottom: 1080, left: 1080 }
            }
        },
        children: [
            // COVER
            new Paragraph({ spacing: { before: 2000 } }),
            new Paragraph({ alignment: AlignmentType.CENTER, children: [
                new TextRun({ text: "HOTSTREAK", bold: true, italics: true, size: 72, font: "Arial", color: c.primaryBlue })
            ]}),
            new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 200 }, children: [
                new TextRun({ text: "SPORTS BETTING APP", bold: true, size: 40, font: "Arial", color: c.glowBlue })
            ]}),
            new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 600 }, children: [
                new TextRun({ text: "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", bold: true, size: 24, color: c.accentCyan })
            ]}),
            new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 100 }, children: [
                new TextRun({ text: "COMPREHENSIVE STYLE GUIDE", bold: true, italics: true, size: 48, font: "Arial", color: c.accentCyan })
            ]}),
            new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 400 }, children: [
                new TextRun({ text: "Blue Aura Theme • Liquid Glass Design • Round & Clean", bold: true, size: 28, font: "Arial", color: c.lightGray })
            ]}),
            new Paragraph({ alignment: AlignmentType.CENTER, children: [
                new TextRun({ text: "Font: Loar Italic Bold 600 (Headers) • Loar Bold 600 (Body)", bold: true, size: 20, font: "Arial", color: c.lightGray })
            ]}),

            // TABLE OF CONTENTS
            new Paragraph({ children: [new PageBreak()] }),
            new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 400 }, children: [
                new TextRun({ text: "TABLE OF CONTENTS", bold: true, italics: true, size: 40, font: "Arial", color: c.primaryBlue })
            ]}),
            body("1.  Design Philosophy .......................... 3"),
            body("2.  Color System - Blue Aura Palette ........... 4"),
            body("3.  Typography - Loar Font System .............. 6"),
            body("4.  Spacing & Layout Grid ...................... 8"),
            body("5.  Border Radius - Round & Clean .............. 9"),
            body("6.  Liquid Glass Design System ................. 10"),
            body("7.  Shadows, Glows & Effects ................... 12"),
            body("8.  Component Library .......................... 14"),
            body("9.  Home Tab Styling ........................... 21"),
            body("10. Games Tab Styling .......................... 24"),
            body("11. My Picks Tab Styling ....................... 27"),
            body("12. Live Tab Styling ........................... 30"),
            body("13. Profile Tab Styling ........................ 33"),
            body("14. Bet Slip Styling ........................... 36"),
            body("15. Wallet Screen .............................. 38"),
            body("16. Spin Wheel & Gamification .................. 40"),
            body("17. Navigation & Bottom Bar .................... 42"),
            body("18. Animations & Transitions ................... 44"),
            body("19. Sport-Specific Colors ...................... 46"),
            body("20. CSS Variables (Copy-Paste) ................. 48"),

            // 1. DESIGN PHILOSOPHY
            new Paragraph({ children: [new PageBreak()] }),
            header("1. DESIGN PHILOSOPHY"),
            body("HotStreak embraces a Blue Aura aesthetic with liquid glass morphism that creates depth, elegance, and a premium betting experience."),
            subHeader("Core Design Pillars"),
            table(["PILLAR", "DESCRIPTION", "IMPLEMENTATION"], [
                ["Blue Aura Theme", "Glowing blue tones create energy", "Cyan/blue gradients, glow effects"],
                ["Liquid Glass", "Frosted translucent surfaces", "backdrop-blur, rgba overlays"],
                ["Round & Clean", "Soft corners, generous padding", "16-32px radius everywhere"],
                ["Premium Feel", "Casino-quality visual language", "Gold accents, smooth animations"],
                ["Dark Mode First", "Deep navy backgrounds", "#0A1628 base, white text hierarchy"]
            ]),
            subHeader("Design Principles"),
            bullet("Hierarchy Through Light", "Important elements glow brighter. CTAs have strongest blue aura."),
            bullet("Consistent Roundness", "Every corner is rounded. No sharp edges. Friendly, approachable feel."),
            bullet("Glass Layering", "Cards float on glass surfaces. Modals have frosted backgrounds."),
            bullet("Motion with Purpose", "Every animation reinforces action. Wins glow. Losses fade."),
            bullet("Typography Weight", "All text uses Loar Bold 600. Headers add italic for emphasis."),

            // 2. COLOR SYSTEM
            new Paragraph({ children: [new PageBreak()] }),
            header("2. COLOR SYSTEM - BLUE AURA PALETTE"),
            subHeader("Primary Colors"),
            table(["COLOR NAME", "HEX CODE", "RGB", "USAGE"], [
                ["Primary Blue", "#0066FF", "rgb(0, 102, 255)", "Main CTAs, links, active states"],
                ["Glow Blue", "#00A3FF", "rgb(0, 163, 255)", "Highlights, hover states, aura"],
                ["Accent Cyan", "#00D4FF", "rgb(0, 212, 255)", "Live indicators, winning states"],
                ["Deep Blue", "#0A1628", "rgb(10, 22, 40)", "Primary background, app base"],
                ["Glass Blue", "#1E3A5F", "rgb(30, 58, 95)", "Card backgrounds, overlays"],
                ["Soft Blue", "#1A3A5C", "rgb(26, 58, 92)", "Secondary backgrounds"],
                ["Ice Blue", "#E0F4FF", "rgb(224, 244, 255)", "Light accents, table alternates"]
            ]),
            subHeader("Semantic Colors"),
            table(["COLOR NAME", "HEX CODE", "USAGE"], [
                ["Success Green", "#00FF7F", "Winning bets, confirmations"],
                ["Error Red", "#FF3B30", "Losing bets, errors"],
                ["Warning Gold", "#FFD700", "Coins, rewards, premium"],
                ["Live Red", "#FF416C", "Live game indicators"]
            ]),
            subHeader("Text Colors"),
            table(["LEVEL", "COLOR", "OPACITY", "USAGE"], [
                ["Text Primary", "#FFFFFF", "95%", "Headlines, important content"],
                ["Text Secondary", "#FFFFFF", "70%", "Body text, descriptions"],
                ["Text Muted", "#FFFFFF", "50%", "Captions, timestamps"],
                ["Text Disabled", "#FFFFFF", "30%", "Disabled states, placeholders"]
            ]),
            subHeader("Border Colors"),
            table(["TYPE", "COLOR", "OPACITY", "USAGE"], [
                ["Subtle Border", "#FFFFFF", "5%", "Card separators, dividers"],
                ["Default Border", "#FFFFFF", "10%", "Input fields, card borders"],
                ["Active Border", "#00A3FF", "100%", "Focus states, selected items"],
                ["Glow Border", "#00D4FF", "30%", "Glass effect borders"]
            ]),

            // 3. TYPOGRAPHY
            new Paragraph({ children: [new PageBreak()] }),
            header("3. TYPOGRAPHY - LOAR FONT SYSTEM"),
            body("Primary Font: Loar (Fallback: Public Sans, Arial, system-ui)"),
            subHeader("Font Weights"),
            table(["STYLE NAME", "WEIGHT", "ITALIC", "CSS"], [
                ["Loar Bold", "600", "No", "font-weight: 600; font-style: normal;"],
                ["Loar Italic Bold", "600", "Yes", "font-weight: 600; font-style: italic;"]
            ]),
            subHeader("Typography Scale"),
            table(["STYLE", "SIZE", "WEIGHT", "LINE HEIGHT", "USE CASE"], [
                ["Display Large", "48px", "600 Italic", "1.1", "Hero headlines"],
                ["Display Medium", "40px", "600 Italic", "1.15", "Page titles"],
                ["Headline Large", "32px", "600 Italic", "1.2", "Card titles"],
                ["Headline Medium", "24px", "600", "1.25", "Subsection headers"],
                ["Title Large", "20px", "600", "1.3", "List item titles"],
                ["Title Medium", "18px", "600", "1.35", "Buttons, labels"],
                ["Body Large", "16px", "600", "1.5", "Primary body text"],
                ["Body Medium", "14px", "600", "1.5", "Secondary body text"],
                ["Body Small", "12px", "600", "1.4", "Captions, timestamps"],
                ["Label", "11px", "600", "1.3", "Chips, badges, tags"]
            ]),
            subHeader("Typography Rules"),
            bullet("Headers", "Always use Loar Italic Bold 600. Page titles, section headers, modal titles."),
            bullet("Body Text", "Always use Loar Bold 600 (non-italic). Maintains readability."),
            bullet("Numbers & Odds", "Use tabular figures. Monospace for live scores."),
            bullet("Button Text", "Title Medium (18px) for primary, Body Medium (14px) for secondary."),

            // 4. SPACING
            new Paragraph({ children: [new PageBreak()] }),
            header("4. SPACING & LAYOUT GRID"),
            subHeader("Spacing Scale"),
            table(["TOKEN", "VALUE", "REM", "USE CASE"], [
                ["space-xxs", "2px", "0.125rem", "Icon padding"],
                ["space-xs", "4px", "0.25rem", "Inline spacing"],
                ["space-sm", "8px", "0.5rem", "Tight groupings"],
                ["space-md", "12px", "0.75rem", "Default spacing"],
                ["space-lg", "16px", "1rem", "Card padding"],
                ["space-xl", "20px", "1.25rem", "Large spacing"],
                ["space-xxl", "24px", "1.5rem", "Page margins"],
                ["space-xxxl", "32px", "2rem", "Hero spacing"],
                ["space-huge", "48px", "3rem", "Page headers"]
            ]),
            subHeader("Layout Grid"),
            table(["PROPERTY", "VALUE", "NOTES"], [
                ["Page Margin", "16px (mobile) / 24px (tablet)", "Horizontal padding"],
                ["Card Gap", "12px", "Space between cards"],
                ["Section Gap", "24px", "Major sections"],
                ["Content Max Width", "500px", "Mobile-first container"],
                ["Bottom Nav Height", "80px", "Fixed navigation"],
                ["FAB Size", "56px", "Floating action button"]
            ]),

            // 5. BORDER RADIUS
            new Paragraph({ children: [new PageBreak()] }),
            header("5. BORDER RADIUS - ROUND & CLEAN"),
            body("Every element uses rounded corners. No sharp edges anywhere."),
            subHeader("Radius Scale"),
            table(["TOKEN", "VALUE", "USE CASE"], [
                ["radius-xs", "4px", "Small badges, inline tags"],
                ["radius-sm", "8px", "Input fields, chips"],
                ["radius-md", "12px", "Standard buttons, list items"],
                ["radius-lg", "16px", "Cards, containers"],
                ["radius-xl", "20px", "Modal dialogs"],
                ["radius-xxl", "24px", "Large cards, feature containers"],
                ["radius-xxxl", "32px", "Hero cards, bet slip"],
                ["radius-round", "9999px", "Pills, circular buttons"]
            ]),
            subHeader("Component Radius Mapping"),
            table(["COMPONENT", "RADIUS", "NOTES"], [
                ["Primary Buttons", "24px", "Pill-shaped CTAs"],
                ["Secondary Buttons", "20px", "Slightly softer"],
                ["Game Cards", "24px", "Large, prominent"],
                ["Bet Slip Cards", "32px", "Extra rounded, premium"],
                ["Input Fields", "12px", "Standard form radius"],
                ["Chips/Tags", "9999px", "Fully rounded pills"],
                ["Modals", "24px (top)", "Rounded top only"],
                ["Bottom Sheets", "24px (top)", "Matches modals"],
                ["Avatars", "9999px", "Perfect circles"],
                ["Sport Icons", "12px", "Soft square icons"]
            ]),

            // 6. LIQUID GLASS
            new Paragraph({ children: [new PageBreak()] }),
            header("6. LIQUID GLASS DESIGN SYSTEM"),
            subHeader("Glass Effect Properties"),
            table(["PROPERTY", "VALUE", "CSS PROPERTY"], [
                ["Background", "rgba(30, 58, 95, 0.6)", "background-color"],
                ["Backdrop Blur", "20px", "backdrop-filter: blur(20px)"],
                ["Border", "1px solid rgba(0, 163, 255, 0.3)", "border"],
                ["Inner Highlight", "inset 0 1px 0 rgba(255,255,255,0.1)", "box-shadow"],
                ["Outer Glow", "0 0 30px rgba(0, 212, 255, 0.15)", "box-shadow"]
            ]),
            subHeader("Glass Layers"),
            table(["LAYER", "OPACITY", "BLUR", "USE CASE"], [
                ["Base Layer", "N/A", "N/A", "Deep Blue #0A1628 solid"],
                ["Surface Layer", "70%", "15px", "Card backgrounds"],
                ["Overlay Layer", "50%", "20px", "Modals, popups"],
                ["Highlight Layer", "30%", "25px", "Tooltips, dropdowns"]
            ]),
            subHeader("Glass Card CSS"),
            ...code([
                ".glass-card {",
                "  background: rgba(30, 58, 95, 0.6);",
                "  backdrop-filter: blur(20px);",
                "  -webkit-backdrop-filter: blur(20px);",
                "  border: 1px solid rgba(0, 163, 255, 0.3);",
                "  border-radius: 24px;",
                "  box-shadow:",
                "    0 0 30px rgba(0, 212, 255, 0.15),",
                "    inset 0 1px 0 rgba(255, 255, 255, 0.1);",
                "}"
            ]),
            subHeader("Glass Variants"),
            table(["VARIANT", "BG OPACITY", "BORDER COLOR", "USE CASE"], [
                ["Default Glass", "60%", "rgba(0, 163, 255, 0.3)", "Standard cards"],
                ["Elevated Glass", "70%", "rgba(0, 212, 255, 0.4)", "Modals"],
                ["Subtle Glass", "40%", "rgba(255, 255, 255, 0.1)", "Backgrounds"],
                ["Active Glass", "80%", "rgba(0, 102, 255, 0.5)", "Selected states"],
                ["Live Glass", "60%", "rgba(255, 65, 108, 0.4)", "Live games"]
            ]),

            // 7. SHADOWS & EFFECTS
            new Paragraph({ children: [new PageBreak()] }),
            header("7. SHADOWS, GLOWS & EFFECTS"),
            subHeader("Shadow Scale"),
            table(["TOKEN", "VALUE", "USE CASE"], [
                ["shadow-sm", "0 2px 4px rgba(0,0,0,0.2)", "Subtle elevation"],
                ["shadow-md", "0 4px 8px rgba(0,0,0,0.25)", "Cards, buttons"],
                ["shadow-lg", "0 8px 16px rgba(0,0,0,0.3)", "Modals, popups"],
                ["shadow-xl", "0 12px 24px rgba(0,0,0,0.35)", "Floating elements"]
            ]),
            subHeader("Glow Effects"),
            table(["GLOW TYPE", "VALUE", "USE CASE"], [
                ["Primary Glow", "0 0 20px rgba(0,102,255,0.4)", "Primary buttons"],
                ["Cyan Glow", "0 0 30px rgba(0,212,255,0.3)", "Accent elements"],
                ["Success Glow", "0 0 25px rgba(0,255,127,0.35)", "Win states"],
                ["Error Glow", "0 0 25px rgba(255,59,48,0.35)", "Loss states"],
                ["Live Glow", "0 0 20px rgba(255,65,108,0.4)", "Live indicators"],
                ["Gold Glow", "0 0 30px rgba(255,215,0,0.4)", "Coins, rewards"]
            ]),
            subHeader("Gradient Effects"),
            table(["GRADIENT NAME", "START", "END", "USE CASE"], [
                ["Blue Aura", "#0066FF", "#00D4FF", "Primary CTAs"],
                ["Cyan Shift", "#00A3FF", "#00D4FF", "Hover states"],
                ["Gold Premium", "#FFD700", "#FFA500", "Coins, rewards"],
                ["Success Flow", "#00FF7F", "#00D68F", "Win animations"],
                ["Live Pulse", "#FF416C", "#FF4B2B", "Live indicators"],
                ["Deep Ocean", "#0A1628", "#1E3A5F", "Backgrounds"]
            ]),

            // 8. COMPONENTS - BUTTONS
            new Paragraph({ children: [new PageBreak()] }),
            header("8. COMPONENT LIBRARY"),
            subHeader("8.1 Buttons"),
            table(["BUTTON TYPE", "BACKGROUND", "TEXT", "RADIUS", "GLOW"], [
                ["Primary CTA", "Gradient: #0066FF→#00A3FF", "White Bold", "24px", "Primary"],
                ["Secondary", "rgba(30,58,95,0.6)", "White Bold", "20px", "None"],
                ["Outline", "Transparent", "Cyan Bold", "20px", "Subtle"],
                ["Ghost", "Transparent", "White 70%", "12px", "None"],
                ["Danger", "Gradient: #FF3B30→#D32F2F", "White Bold", "20px", "Error"],
                ["Success", "Gradient: #00FF7F→#00D68F", "Deep Blue", "20px", "Success"]
            ]),
            subHeader("Button Sizes"),
            table(["SIZE", "HEIGHT", "PADDING X", "FONT SIZE", "USE CASE"], [
                ["Small", "36px", "16px", "14px", "Inline actions"],
                ["Medium", "44px", "20px", "16px", "Secondary actions"],
                ["Large", "52px", "24px", "18px", "Primary CTAs"],
                ["XLarge", "60px", "32px", "20px", "Hero buttons"]
            ]),
            subHeader("Button States"),
            table(["STATE", "OPACITY", "SCALE", "GLOW", "CURSOR"], [
                ["Default", "100%", "1.0", "100%", "pointer"],
                ["Hover", "100%", "1.02", "150%", "pointer"],
                ["Pressed", "90%", "0.98", "80%", "pointer"],
                ["Disabled", "50%", "1.0", "0%", "not-allowed"],
                ["Loading", "80%", "1.0", "Pulsing", "wait"]
            ]),

            // 8.2 CARDS
            new Paragraph({ children: [new PageBreak()] }),
            subHeader("8.2 Cards"),
            table(["CARD TYPE", "RADIUS", "BACKGROUND", "BORDER", "PADDING"], [
                ["Game Card", "24px", "Glass 60%", "Glow Blue 30%", "16px"],
                ["Bet Slip Card", "32px", "Glass 70%", "Cyan 40%", "20px"],
                ["Stats Card", "20px", "Glass 50%", "White 10%", "16px"],
                ["Profile Card", "24px", "Glass 60%", "None", "20px"],
                ["Prediction Card", "20px", "Glass 60%", "Status color", "16px"],
                ["Feature Card", "28px", "Gradient", "None", "24px"]
            ]),
            subHeader("Card States"),
            table(["STATE", "BORDER COLOR", "GLOW", "EFFECT"], [
                ["Default", "rgba(0,163,255,0.3)", "None", "—"],
                ["Hover", "rgba(0,212,255,0.5)", "Subtle Cyan", "Scale 1.01"],
                ["Selected", "rgba(0,102,255,0.8)", "Primary", "Border 2px"],
                ["Live", "rgba(255,65,108,0.5)", "Red Pulse", "Animated border"],
                ["Won", "rgba(0,255,127,0.5)", "Success", "Green tint"],
                ["Lost", "rgba(255,59,48,0.3)", "None", "Opacity 70%"]
            ]),
            subHeader("Game Card Layout"),
            ...code([
                "┌─────────────────────────────────────────┐",
                "│  [Icon]  League Name           [LIVE]   │",
                "├─────────────────────────────────────────┤",
                "│  [Logo] Team A         2.15      [+]    │",
                "│  [Logo] Team B         1.85      [+]    │",
                "├─────────────────────────────────────────┤",
                "│  Mar 15, 2024 • 7:30 PM EST             │",
                "└─────────────────────────────────────────┘"
            ]),

            // 8.3 INPUT FIELDS
            subHeader("8.3 Input Fields"),
            table(["PROPERTY", "DEFAULT", "FOCUS", "ERROR"], [
                ["Background", "rgba(30,58,95,0.4)", "rgba(30,58,95,0.6)", "rgba(255,59,48,0.1)"],
                ["Border", "1px White 10%", "2px #00A3FF", "2px #FF3B30"],
                ["Border Radius", "12px", "12px", "12px"],
                ["Text Color", "White 95%", "White 100%", "White 95%"],
                ["Placeholder", "White 40%", "White 50%", "White 40%"],
                ["Height", "52px", "52px", "52px"]
            ]),
            subHeader("Input Types"),
            table(["TYPE", "ICON", "SPECIAL STYLING"], [
                ["Text Input", "Left (optional)", "Standard"],
                ["Password", "Right (toggle)", "Eye icon"],
                ["Search", "Left (search)", "Pill radius (9999px)"],
                ["Number/Stake", "Left (coin)", "Gold accent, larger text"],
                ["Dropdown", "Right (chevron)", "Arrow indicator"]
            ]),

            // 8.4 CHIPS & TAGS
            new Paragraph({ children: [new PageBreak()] }),
            subHeader("8.4 Chips & Tags"),
            table(["CHIP TYPE", "BACKGROUND", "TEXT", "RADIUS", "HEIGHT"], [
                ["Sport Filter", "Glass 40%", "White 70%", "9999px", "36px"],
                ["Sport (Active)", "Sport Color 80%", "White 100%", "9999px", "36px"],
                ["Status Tag", "Status Color 20%", "Status Color", "8px", "24px"],
                ["Odds Chip", "Glass 60%", "Cyan Bold", "12px", "40px"],
                ["Odds (Selected)", "Primary Gradient", "White Bold", "12px", "40px"]
            ]),
            subHeader("8.5 Bottom Sheets & Modals"),
            table(["PROPERTY", "BOTTOM SHEET", "MODAL", "POPUP"], [
                ["Background", "Deep Blue solid", "Glass 80%", "Glass 70%"],
                ["Border Radius", "24px (top)", "24px (all)", "20px (all)"],
                ["Backdrop", "Black 50%", "Black 60%", "Black 40%"],
                ["Max Height", "90% viewport", "80% viewport", "Auto"],
                ["Animation", "Slide up 300ms", "Scale+fade 250ms", "Scale 200ms"]
            ]),

            // 9. HOME TAB
            new Paragraph({ children: [new PageBreak()] }),
            header("9. HOME TAB STYLING"),
            body("The Home tab is the primary landing screen featuring featured games, daily bonus wheel, and personalized suggestions."),
            subHeader("Page Elements"),
            table(["ELEMENT", "STYLING", "SPECIFICATIONS"], [
                ["Page Background", "Deep Blue #0A1628", "Solid, no pattern"],
                ["Header", "Transparent overlay", "Coin balance + profile icon"],
                ["Welcome Section", "None (text only)", "Display Large, White 95%"],
                ["Featured Carousel", "Horizontal scroll", "Card width: 300px, gap: 16px"],
                ["Daily Spin Banner", "Gold gradient border", "Radius 24px, animated glow"],
                ["Suggestions", "Standard cards", "Vertical list, 12px gap"],
                ["Quick Picks", "Horizontal chips", "Pill chips, sport colors"]
            ]),
            subHeader("Featured Game Card"),
            table(["PROPERTY", "VALUE"], [
                ["Width", "300px (carousel item)"],
                ["Height", "180px"],
                ["Background", "Glass 60% + blur 20px"],
                ["Border", "1px rgba(0,163,255,0.3)"],
                ["Border Radius", "24px"],
                ["Padding", "20px"],
                ["Shadow", "0 8px 32px rgba(0,0,0,0.3)"]
            ]),
            subHeader("Daily Bonus Section"),
            table(["PROPERTY", "VALUE"], [
                ["Container BG", "Gold gradient at 10% opacity"],
                ["Border", "2px solid rgba(255,215,0,0.5)"],
                ["Border Radius", "24px"],
                ["CTA Button", "Gold gradient, Deep Blue text"],
                ["Icon", "Spin wheel emoji + glow"],
                ["Text", "Loar Italic Bold, Gold color"]
            ]),

            // 10. GAMES TAB
            new Paragraph({ children: [new PageBreak()] }),
            header("10. GAMES TAB STYLING"),
            body("The Games tab displays all available matches with sport filtering and personalized recommendations."),
            subHeader("Page Elements"),
            table(["ELEMENT", "STYLING", "SPECIFICATIONS"], [
                ["Page Header", "\"Games\" title", "Headline Large, Italic Bold"],
                ["Sport Filter Bar", "Horizontal scroll", "Pill chips, 8px gap, sticky"],
                ["For You Section", "Highlighted header", "Cyan accent, star icon"],
                ["Game List", "Vertical scroll", "12px gap between cards"],
                ["Empty State", "Centered message", "Illustration + text + CTA"],
                ["Loading State", "Shimmer effect", "3 placeholder cards"]
            ]),
            subHeader("Sport Filter Chips"),
            table(["STATE", "BACKGROUND", "TEXT", "BORDER"], [
                ["Default", "rgba(30,58,95,0.4)", "White 70%", "1px White 10%"],
                ["Selected", "Sport Color 80%", "White 100%", "2px Sport Color"],
                ["Hover", "rgba(30,58,95,0.6)", "White 85%", "1px White 20%"]
            ]),
            subHeader("Game Card (List View)"),
            table(["PROPERTY", "VALUE"], [
                ["Width", "100% - 32px (page margins)"],
                ["Min Height", "140px"],
                ["Background", "Glass 60%"],
                ["Border", "1px rgba(0,163,255,0.25)"],
                ["Border Radius", "24px"],
                ["Padding", "16px"],
                ["Team Logo Size", "40px × 40px, radius 8px"],
                ["Odds Button", "60px × 40px, radius 12px"]
            ]),
            subHeader("Odds Button States"),
            table(["STATE", "BACKGROUND", "TEXT", "EFFECT"], [
                ["Default", "Glass 50%", "Cyan Bold", "None"],
                ["Hover", "Glass 70%", "White Bold", "Subtle glow"],
                ["Selected", "Primary Gradient", "White Bold", "Primary glow"],
                ["Disabled", "Glass 30%", "White 40%", "None"]
            ]),

            // 11. MY PICKS TAB
            new Paragraph({ children: [new PageBreak()] }),
            header("11. MY PICKS TAB STYLING"),
            body("The My Picks tab shows the user's betting history with filtering by status."),
            subHeader("Page Elements"),
            table(["ELEMENT", "STYLING", "SPECIFICATIONS"], [
                ["Page Header", "\"My Picks\" title", "Headline Large, Italic Bold"],
                ["Status Tabs", "Segmented control", "3 tabs: Pending, Won, Lost"],
                ["Summary Stats", "3-column grid", "Total bets, Win rate, Profit"],
                ["Prediction List", "Vertical scroll", "12px gap, grouped by date"],
                ["Date Headers", "Section dividers", "Body Small, White 50%"],
                ["Empty State", "Centered", "\"No picks yet\" + CTA"]
            ]),
            subHeader("Status Tab Styling"),
            table(["TAB", "INACTIVE BG", "ACTIVE BG", "TEXT COLOR"], [
                ["Pending", "Transparent", "rgba(0,163,255,0.2)", "Cyan"],
                ["Won", "Transparent", "rgba(0,255,127,0.2)", "Success Green"],
                ["Lost", "Transparent", "rgba(255,59,48,0.2)", "Error Red"]
            ]),
            subHeader("Prediction Card"),
            table(["PROPERTY", "PENDING", "WON", "LOST"], [
                ["Background", "Glass 60%", "Glass 60% + green", "Glass 40%"],
                ["Border", "1px Cyan 30%", "1px Success 50%", "1px Error 30%"],
                ["Left Accent", "None", "4px Success bar", "4px Error bar"],
                ["Opacity", "100%", "100%", "70%"],
                ["Badge BG", "Cyan 20%", "Success 20%", "Error 20%"]
            ]),
            subHeader("Prediction Card Layout"),
            ...code([
                "┌─────────────────────────────────────────┐",
                "│ [Bar] │ Team A vs Team B      [Status]  │",
                "│       │ Your Pick: Team A ML +2.15      │",
                "│       │ Stake: 500  →  Payout: 1,075    │",
                "│       │ Mar 15, 2024              [···] │",
                "└─────────────────────────────────────────┘"
            ]),

            // 12. LIVE TAB
            new Paragraph({ children: [new PageBreak()] }),
            header("12. LIVE TAB STYLING"),
            body("The Live tab displays real-time scores for games currently in progress."),
            subHeader("Page Elements"),
            table(["ELEMENT", "STYLING", "SPECIFICATIONS"], [
                ["Page Header", "\"Live\" + pulsing dot", "Headline Large + red circle"],
                ["Sport Tabs", "Horizontal tabs", "Sport icons + names, scrollable"],
                ["Live Game Cards", "Prominent styling", "Animated border, live glow"],
                ["Score Display", "Large numerals", "48px, Loar Bold, tabular"],
                ["Time/Period", "Badge style", "Red background, white text"],
                ["Auto-Refresh", "Indicator", "Subtle spinning icon"]
            ]),
            subHeader("Live Game Card"),
            table(["PROPERTY", "VALUE"], [
                ["Background", "Glass 60%"],
                ["Border", "2px animated gradient (Live Pulse)"],
                ["Border Radius", "24px"],
                ["Glow", "0 0 30px rgba(255,65,108,0.25)"],
                ["Animation", "Border gradient rotation 3s"],
                ["Padding", "20px"]
            ]),
            subHeader("Score Display"),
            table(["PROPERTY", "VALUE"], [
                ["Font Size", "48px"],
                ["Font Weight", "600 (Loar Bold)"],
                ["Color", "White 100%"],
                ["Font Feature", "tabular-nums (monospace)"],
                ["Alignment", "Center"],
                ["Separator", "\" - \" in White 50%"]
            ]),
            subHeader("Period/Time Badge"),
            table(["PROPERTY", "VALUE"], [
                ["Background", "rgba(255,65,108,0.8)"],
                ["Text", "White Bold, 12px"],
                ["Padding", "4px 12px"],
                ["Border Radius", "9999px (pill)"],
                ["Animation", "Subtle pulse every 2s"]
            ]),

            // 13. PROFILE TAB
            new Paragraph({ children: [new PageBreak()] }),
            header("13. PROFILE TAB STYLING"),
            body("The Profile tab displays user statistics, XP progression, achievements, and settings."),
            subHeader("Page Elements"),
            table(["ELEMENT", "STYLING", "SPECIFICATIONS"], [
                ["Avatar", "Circular, 80px", "Border: 3px Primary gradient"],
                ["Username", "Display Medium", "Loar Italic Bold, White"],
                ["Level Badge", "Pill badge", "Gold gradient BG"],
                ["XP Progress Bar", "Horizontal bar", "Gradient fill, animated"],
                ["Stats Grid", "3-column grid", "Glass cards, 16px gap"],
                ["Achievements", "Horizontal scroll", "Badge cards"],
                ["Settings Links", "List items", "Chevron right, dividers"]
            ]),
            subHeader("XP Progress Bar"),
            table(["PROPERTY", "VALUE"], [
                ["Container BG", "rgba(30,58,95,0.4)"],
                ["Container Height", "12px"],
                ["Container Radius", "6px"],
                ["Fill Gradient", "#0066FF → #00D4FF"],
                ["Fill Animation", "Width 500ms ease-out"],
                ["Glow Effect", "0 0 10px rgba(0,212,255,0.5)"]
            ]),
            subHeader("Stats Card"),
            table(["PROPERTY", "VALUE"], [
                ["Background", "Glass 50%"],
                ["Border", "1px White 10%"],
                ["Border Radius", "16px"],
                ["Padding", "16px"],
                ["Stat Value", "Headline Large, Cyan"],
                ["Stat Label", "Body Small, White 60%"]
            ]),
            subHeader("Achievement Badge Rarity"),
            table(["RARITY", "BORDER", "GLOW", "BG TINT"], [
                ["Common", "#AAAAAA", "None", "Gray 10%"],
                ["Rare", "#00A3FF", "Blue glow", "Blue 10%"],
                ["Epic", "#9B59B6", "Purple glow", "Purple 10%"],
                ["Legendary", "#FFD700", "Gold + particles", "Gold 15%"]
            ]),

            // 14. BET SLIP
            new Paragraph({ children: [new PageBreak()] }),
            header("14. BET SLIP STYLING"),
            subHeader("Bet Slip Container"),
            table(["PROPERTY", "VALUE"], [
                ["Type", "Bottom Sheet (full height modal)"],
                ["Background", "Deep Blue #0A1628 solid"],
                ["Border Radius", "32px (top corners only)"],
                ["Handle Bar", "40px × 4px, White 30%, centered"],
                ["Header Height", "60px"],
                ["Padding", "24px horizontal, 16px vertical"]
            ]),
            subHeader("Bet Slip Item Card"),
            table(["PROPERTY", "VALUE"], [
                ["Background", "Glass 60%"],
                ["Border", "1px rgba(0,163,255,0.3)"],
                ["Border Radius", "20px"],
                ["Padding", "16px"],
                ["Delete Button", "Red ghost button, right"],
                ["Odds Display", "Cyan Bold, 20px"],
                ["Team Names", "White Bold, 16px"]
            ]),
            subHeader("Stake Input Field"),
            table(["PROPERTY", "VALUE"], [
                ["Background", "Glass 40%"],
                ["Border", "2px rgba(255,215,0,0.5)"],
                ["Border Radius", "16px"],
                ["Height", "60px"],
                ["Font Size", "24px, Loar Bold"],
                ["Icon", "Coin icon, left, gold"],
                ["Focus Border", "2px solid #FFD700"]
            ]),
            subHeader("Quick Stake Buttons"),
            table(["PROPERTY", "VALUE"], [
                ["Layout", "4 buttons, horizontal row"],
                ["Values", "+100, +250, +500, MAX"],
                ["Background", "Glass 50%"],
                ["Border", "1px White 20%"],
                ["Border Radius", "12px"],
                ["Text", "Body Medium, White Bold"]
            ]),
            subHeader("Place Bet Button"),
            table(["PROPERTY", "VALUE"], [
                ["Background", "Gradient: #0066FF → #00A3FF"],
                ["Text", "\"PLACE BET\" 20px Loar Bold White"],
                ["Height", "60px"],
                ["Border Radius", "24px"],
                ["Glow", "0 0 30px rgba(0,102,255,0.4)"],
                ["Disabled", "Gray gradient, no glow, 50%"]
            ]),

            // 15. WALLET
            new Paragraph({ children: [new PageBreak()] }),
            header("15. WALLET SCREEN STYLING"),
            subHeader("Wallet Header"),
            table(["PROPERTY", "VALUE"], [
                ["Background", "Deep Blue with subtle gradient"],
                ["Balance Display", "64px, Italic Bold, Gold gradient"],
                ["Coin Icon", "48px, animated subtle rotation"],
                ["Glow Effect", "0 0 60px rgba(255,215,0,0.3)"],
                ["Label", "\"Your Balance\" Body Medium, White 70%"]
            ]),
            subHeader("Daily Bonus Card"),
            table(["PROPERTY", "VALUE"], [
                ["Background", "Gold gradient at 10% opacity"],
                ["Border", "2px dashed rgba(255,215,0,0.5)"],
                ["Border Radius", "24px"],
                ["Icon", "Gift/Spin emoji, 32px"],
                ["CTA", "\"Claim Bonus\" Gold style"],
                ["Timer", "Countdown, Body Small"]
            ]),
            subHeader("Transaction Types"),
            table(["TYPE", "ICON", "AMOUNT COLOR", "PREFIX"], [
                ["Bet Placed", "Arrow down", "Error Red", "-"],
                ["Bet Won", "Trophy", "Success Green", "+"],
                ["Bet Lost", "X mark", "White 50%", "—"],
                ["Daily Bonus", "Gift", "Gold", "+"],
                ["Spin Win", "Star", "Gold", "+"],
                ["Level Up", "Arrow up", "Cyan", "+"]
            ]),
            subHeader("Transaction Item"),
            table(["PROPERTY", "VALUE"], [
                ["Background", "Transparent"],
                ["Border Bottom", "1px White 5%"],
                ["Padding", "16px 0"],
                ["Icon Size", "24px, in colored circle"],
                ["Description", "Body Medium, White 80%"],
                ["Timestamp", "Body Small, White 50%"],
                ["Amount", "Title Large, transaction color"]
            ]),

            // 16. SPIN WHEEL
            new Paragraph({ children: [new PageBreak()] }),
            header("16. SPIN WHEEL & GAMIFICATION"),
            subHeader("Spin Wheel Modal"),
            table(["PROPERTY", "VALUE"], [
                ["Backdrop", "Black 80% + heavy blur"],
                ["Container", "Centered, max-width 400px"],
                ["Background", "Deep Blue solid"],
                ["Border Radius", "32px"],
                ["Padding", "32px"]
            ]),
            subHeader("Wheel Design"),
            table(["PROPERTY", "VALUE"], [
                ["Size", "300px × 300px"],
                ["Segments", "8-12 prize segments"],
                ["Border", "8px metallic gold gradient"],
                ["Center Hub", "60px circle, gold, logo"],
                ["Pointer", "Triangle at top, gold with glow"],
                ["Lights", "24 LEDs around rim, animated"]
            ]),
            subHeader("Wheel Segment Colors"),
            table(["PRIZE TIER", "BACKGROUND", "TEXT"], [
                ["50 Coins", "#1A3A5C (Soft Blue)", "White"],
                ["100 Coins", "#0066FF (Primary)", "White"],
                ["250 Coins", "#00A3FF (Glow Blue)", "White"],
                ["500 Coins", "#00D4FF (Cyan)", "Deep Blue"],
                ["1000 Coins", "#00FF7F (Success)", "Deep Blue"],
                ["JACKPOT", "#FFD700 (Gold)", "Deep Blue"]
            ]),
            subHeader("Spin Animation"),
            table(["PHASE", "DURATION", "EASING", "ROTATIONS"], [
                ["Acceleration", "1000ms", "ease-in", "1-2"],
                ["Full Speed", "3000ms", "linear", "4-5"],
                ["Deceleration", "1500ms", "ease-out", "1"],
                ["Settle", "500ms", "ease-out", "Minor"]
            ]),
            subHeader("Win Celebration"),
            table(["ELEMENT", "SPECIFICATION"], [
                ["Confetti", "100+ particles, gold/cyan, 3s"],
                ["Coin Rain", "20 coins falling, gold glow"],
                ["Prize Display", "Scale in, 48px gold text"],
                ["Sound", "Coin jingle + celebration"],
                ["Haptics", "Heavy impact on win"]
            ]),

            // 17. NAVIGATION
            new Paragraph({ children: [new PageBreak()] }),
            header("17. NAVIGATION & BOTTOM BAR"),
            subHeader("Bottom Navigation Bar"),
            table(["PROPERTY", "VALUE"], [
                ["Background", "Deep Blue #0A1628"],
                ["Top Border", "1px rgba(255,255,255,0.1)"],
                ["Height", "80px (including safe area)"],
                ["Padding", "8px 16px 24px (safe area)"],
                ["Items", "4 tabs + centered FAB"]
            ]),
            subHeader("Navigation Items"),
            table(["STATE", "ICON COLOR", "LABEL", "BACKGROUND"], [
                ["Inactive", "White 50%", "White 40%", "Transparent"],
                ["Active", "Cyan 100%", "Cyan 100%", "Cyan 10% pill"],
                ["Pressed", "Cyan 80%", "Cyan 80%", "Cyan 15%"]
            ]),
            subHeader("Floating Action Button"),
            table(["PROPERTY", "VALUE"], [
                ["Size", "56px × 56px"],
                ["Position", "Centered, elevated above nav"],
                ["Background", "Gradient: #0066FF → #00A3FF"],
                ["Icon", "Bet slip icon, 24px, white"],
                ["Border Radius", "28px (circle)"],
                ["Shadow", "0 4px 20px rgba(0,102,255,0.4)"],
                ["Badge", "Red circle, item count, top-right"]
            ]),
            subHeader("FAB Badge"),
            table(["PROPERTY", "VALUE"], [
                ["Size", "20px × 20px minimum"],
                ["Position", "Top right, offset -4px"],
                ["Background", "#FF3B30 (Error Red)"],
                ["Text", "12px, White Bold, centered"],
                ["Border", "2px Deep Blue"],
                ["Border Radius", "9999px"]
            ]),

            // 18. ANIMATIONS
            new Paragraph({ children: [new PageBreak()] }),
            header("18. ANIMATIONS & TRANSITIONS"),
            subHeader("Timing Functions"),
            table(["NAME", "CSS VALUE", "USE CASE"], [
                ["ease-smooth", "cubic-bezier(0.4,0,0.2,1)", "General transitions"],
                ["ease-bounce", "cubic-bezier(0.68,-0.55,0.265,1.55)", "Playful elements"],
                ["ease-in", "cubic-bezier(0.4,0,1,1)", "Exit animations"],
                ["ease-out", "cubic-bezier(0,0,0.2,1)", "Enter animations"],
                ["linear", "linear", "Continuous animations"]
            ]),
            subHeader("Duration Scale"),
            table(["TOKEN", "VALUE", "USE CASE"], [
                ["instant", "50ms", "Micro-interactions"],
                ["fast", "150ms", "Button feedback"],
                ["normal", "250ms", "Standard transitions"],
                ["slow", "400ms", "Page transitions"],
                ["slower", "600ms", "Complex animations"]
            ]),
            subHeader("Common Animations"),
            table(["ANIMATION", "PROPERTIES", "DURATION", "EASING"], [
                ["Fade In", "opacity: 0 → 1", "250ms", "ease-out"],
                ["Slide Up", "translateY: 20px → 0", "300ms", "ease-out"],
                ["Scale In", "scale: 0.95 → 1", "200ms", "ease-bounce"],
                ["Glow Pulse", "box-shadow opacity", "1500ms", "ease-in-out"],
                ["Shake Error", "translateX: ±5px", "400ms", "ease-smooth"],
                ["Bounce", "scale: 1 → 1.1 → 1", "300ms", "ease-bounce"]
            ]),
            subHeader("List Stagger Animation"),
            ...code([
                "/* Each item delays by index * 50ms */",
                ".list-item {",
                "  animation: fadeSlideIn 300ms ease-out;",
                "  animation-delay: calc(var(--index) * 50ms);",
                "}",
                "",
                "@keyframes fadeSlideIn {",
                "  from { opacity: 0; transform: translateX(-10px); }",
                "  to { opacity: 1; transform: translateX(0); }",
                "}"
            ]),

            // 19. SPORT COLORS
            new Paragraph({ children: [new PageBreak()] }),
            header("19. SPORT-SPECIFIC COLORS"),
            table(["SPORT", "PRIMARY COLOR", "HEX", "EMOJI"], [
                ["NFL", "Navy Blue", "#013369", "🏈"],
                ["NBA", "Orange/Red", "#C8102E", "🏀"],
                ["Soccer (EPL)", "Purple", "#38003C", "⚽"],
                ["Soccer (La Liga)", "Orange", "#FF4B44", "⚽"],
                ["Soccer (Champions)", "Navy", "#0D1541", "⚽"],
                ["Soccer (MLS)", "Blue", "#0033A0", "⚽"],
                ["NHL", "Black/Silver", "#000000", "🏒"],
                ["MLB", "Red/Blue", "#002D72", "⚾"],
                ["NCAA Football", "Brown", "#8B4513", "🏈"],
                ["NCAA Basketball", "Orange", "#FF6B00", "🏀"]
            ]),
            subHeader("Sport Color Usage"),
            bullet("Sport Filter Chips", "Selected state uses sport color as background at 80% opacity."),
            bullet("Game Cards", "Sport icon badge uses sport color. Subtle tint on card hover."),
            bullet("Tab Headers", "Active sport tab in Live screen uses sport color underline."),

            // 20. CSS VARIABLES
            new Paragraph({ children: [new PageBreak()] }),
            header("20. CSS VARIABLES (COPY-PASTE)"),
            body("Copy this complete CSS variable set to implement the Blue Aura theme:"),
            ...code([
                ":root {",
                "  /* ===== COLORS ===== */",
                "  --color-primary-blue: #0066FF;",
                "  --color-glow-blue: #00A3FF;",
                "  --color-accent-cyan: #00D4FF;",
                "  --color-deep-blue: #0A1628;",
                "  --color-glass-blue: #1E3A5F;",
                "  --color-soft-blue: #1A3A5C;",
                "  --color-ice-blue: #E0F4FF;",
                "  --color-success: #00FF7F;",
                "  --color-error: #FF3B30;",
                "  --color-warning: #FFD700;",
                "  --color-live: #FF416C;",
                "",
                "  /* ===== TEXT ===== */",
                "  --text-primary: rgba(255, 255, 255, 0.95);",
                "  --text-secondary: rgba(255, 255, 255, 0.70);",
                "  --text-muted: rgba(255, 255, 255, 0.50);",
                "  --text-disabled: rgba(255, 255, 255, 0.30);",
                "",
                "  /* ===== TYPOGRAPHY ===== */",
                "  --font-family: 'Loar', 'Public Sans', Arial, sans-serif;",
                "  --font-weight-bold: 600;",
                "",
                "  /* ===== SPACING ===== */",
                "  --space-xxs: 2px;  --space-xs: 4px;",
                "  --space-sm: 8px;   --space-md: 12px;",
                "  --space-lg: 16px;  --space-xl: 20px;",
                "  --space-xxl: 24px; --space-xxxl: 32px;",
                "",
                "  /* ===== BORDER RADIUS ===== */",
                "  --radius-xs: 4px;   --radius-sm: 8px;",
                "  --radius-md: 12px;  --radius-lg: 16px;",
                "  --radius-xl: 20px;  --radius-xxl: 24px;",
                "  --radius-xxxl: 32px; --radius-round: 9999px;",
                "",
                "  /* ===== GLASS EFFECT ===== */",
                "  --glass-bg: rgba(30, 58, 95, 0.6);",
                "  --glass-blur: 20px;",
                "  --glass-border: rgba(0, 163, 255, 0.3);",
                "",
                "  /* ===== SHADOWS ===== */",
                "  --shadow-sm: 0 2px 4px rgba(0, 0, 0, 0.2);",
                "  --shadow-md: 0 4px 8px rgba(0, 0, 0, 0.25);",
                "  --shadow-lg: 0 8px 16px rgba(0, 0, 0, 0.3);",
                "",
                "  /* ===== GLOWS ===== */",
                "  --glow-primary: 0 0 20px rgba(0, 102, 255, 0.4);",
                "  --glow-cyan: 0 0 30px rgba(0, 212, 255, 0.3);",
                "  --glow-success: 0 0 25px rgba(0, 255, 127, 0.35);",
                "  --glow-gold: 0 0 30px rgba(255, 215, 0, 0.4);",
                "",
                "  /* ===== GRADIENTS ===== */",
                "  --gradient-primary: linear-gradient(135deg, #0066FF, #00A3FF);",
                "  --gradient-cyan: linear-gradient(135deg, #00A3FF, #00D4FF);",
                "  --gradient-gold: linear-gradient(135deg, #FFD700, #FFA500);",
                "  --gradient-success: linear-gradient(135deg, #00FF7F, #00D68F);",
                "  --gradient-live: linear-gradient(135deg, #FF416C, #FF4B2B);",
                "",
                "  /* ===== ANIMATION ===== */",
                "  --ease-smooth: cubic-bezier(0.4, 0, 0.2, 1);",
                "  --ease-bounce: cubic-bezier(0.68, -0.55, 0.265, 1.55);",
                "  --duration-fast: 150ms;",
                "  --duration-normal: 250ms;",
                "  --duration-slow: 400ms;",
                "}"
            ]),

            // FOOTER
            new Paragraph({ children: [new PageBreak()] }),
            new Paragraph({ spacing: { before: 2000 } }),
            new Paragraph({ alignment: AlignmentType.CENTER, children: [
                new TextRun({ text: "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", bold: true, size: 24, color: c.accentCyan })
            ]}),
            new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 200 }, children: [
                new TextRun({ text: "HOTSTREAK", bold: true, italics: true, size: 48, font: "Arial", color: c.primaryBlue })
            ]}),
            new Paragraph({ alignment: AlignmentType.CENTER, children: [
                new TextRun({ text: "COMPREHENSIVE STYLE GUIDE", bold: true, size: 24, font: "Arial", color: c.glowBlue })
            ]}),
            new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 200 }, children: [
                new TextRun({ text: "Blue Aura Theme • Liquid Glass • Round & Clean", bold: true, italics: true, size: 20, font: "Arial", color: c.lightGray })
            ]}),
            new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 100 }, children: [
                new TextRun({ text: "Version 1.0", bold: true, size: 18, font: "Arial", color: c.lightGray })
            ]})
        ]
    }]
});

Packer.toBuffer(doc).then(buffer => {
    fs.writeFileSync("/sessions/loving-nifty-fermi/mnt/hotstreak/HotStreak_Comprehensive_Style_Guide.docx", buffer);
    console.log("Style Guide created successfully!");
});
