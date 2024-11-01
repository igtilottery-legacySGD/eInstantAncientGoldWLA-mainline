<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:x="anything">
	<xsl:namespace-alias stylesheet-prefix="x" result-prefix="xsl" />
	<xsl:output encoding="UTF-8" indent="yes" method="xml" />
	<xsl:include href="../utils.xsl" />

	<xsl:template match="/Paytable">
		<x:stylesheet version="1.0" xmlns:java="http://xml.apache.org/xslt/java" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
			exclude-result-prefixes="java" xmlns:lxslt="http://xml.apache.org/xslt" xmlns:my-ext="ext1" extension-element-prefixes="my-ext">
			<x:import href="HTML-CCFR.xsl" />
			<x:output indent="no" method="xml" omit-xml-declaration="yes" />

			<!-- TEMPLATE Match: -->
			<x:template match="/">
				<x:apply-templates select="*" />
				<x:apply-templates select="/output/root[position()=last()]" mode="last" />
				<br />
			</x:template>

			<!--The component and its script are in the lxslt namespace and define the implementation of the extension. -->
			<lxslt:component prefix="my-ext" functions="formatJson,retrievePrizeTable,getType">
				<lxslt:script lang="javascript">
					<![CDATA[
					var debugFeed = [];
					var debugFlag = false;
					// Format instant win JSON results.
					// @param jsonContext String JSON results to parse and display.
					// @param translation Set of Translations for the game.
					function formatJson(jsonContext, translations, prizeTable, prizeValues, prizeNamesDesc)
					{
						var scenario             = getScenario(jsonContext);
						var scenarioGrids        = scenario.split('|');
						var convertedPrizeValues = (prizeValues.substring(1)).split('|').map(function(item) {return item.replace(/\t|\r|\n/gm, "")} );
						var prizeNames           = (prizeNamesDesc.substring(1)).split(',');

						////////////////////
						// Parse scenario //
						////////////////////

						const cellTypes     = {iSingle: 1, iPair: 2, iQuad: 4};
						const prizeSymbs    = 'ABCDEFGHIJKL';
						const specialSymbs  = 'Z1';
						const minWinSymbQty = 3;
						const bonusQty      = 3;

						var arrGridParts   = [];
						var arrGrids       = [];
						var arrSplitCells  = [];
						var cellFullIndex  = 0;
						var cellParts      = 0;
						var cellSplitIndex = 5;
						var dataIndex      = 0;
						var gridCellQty    = 9;
						var isSplitCell    = false;
						var objGrid        = {};
						var prizeSymbQty   = prizeSymbs.split('').map(function(item) {return 0} );

						function getSymbCount(A_strString, A_strSymb)
						{
							return A_strString.replace(new RegExp('[^' + A_strSymb + ']', 'g'), '').length;
						}

						for (var gridIndex = 0; gridIndex < scenarioGrids.length; gridIndex++)
						{
							objGrid = {aoGridCells: [], aoPrizes: [], iBonus: 0, iMulti: 0};

							arrGridParts   = scenarioGrids[gridIndex].split(':');
							arrSplitCells  = arrGridParts[0].split(',').join('').split('');
							cellFullIndex  = 0;
							cellSplitIndex = 5;

							objGrid.iBonus = getSymbCount(arrGridParts[1], specialSymbs[0]);
							objGrid.iMulti = getSymbCount(arrGridParts[1], specialSymbs[1]) + 1;

							for (var prizeIndex = 0; prizeIndex < prizeSymbs.length; prizeIndex++)
							{
								objPrize = {sPrizeSymb: '', iPrizeQty: 0};

								prizeSymbQty[prizeIndex] = getSymbCount(arrGridParts[1], prizeSymbs[prizeIndex]);

								if (prizeSymbQty[prizeIndex] >= minWinSymbQty)
								{
									objPrize.sPrizeSymb = prizeSymbs[prizeIndex];
									objPrize.iPrizeQty  = prizeSymbQty[prizeIndex];

									objGrid.aoPrizes.push(objPrize);
								}
							}

							for (var gridCellIndex = 0; gridCellIndex < gridCellQty; gridCellIndex++)
							{
								objGridCell = {aoSplitCells: []};

								isSplitCell = (arrSplitCells.indexOf((gridCellIndex + 1).toString()) != -1);
								cellParts   = (!isSplitCell) ? cellTypes.iSingle : ((gridIndex == 0) ? cellTypes.iPair : cellTypes.iQuad);

								for (var cellPartIndex = 0; cellPartIndex < cellParts; cellPartIndex++)
								{
									objCellPart = {sPrize: ''};

									dataIndex = (isSplitCell) ? cellSplitIndex : cellFullIndex;

									objCellPart.sPrize = arrGridParts[1][dataIndex];

									if (isSplitCell) {cellSplitIndex++} else {cellFullIndex++}

									objGridCell.aoSplitCells.push(objCellPart);
								}

								objGrid.aoGridCells.push(objGridCell);
							}

							arrGrids.push(objGrid);
						}

						/////////////////////////
						// Currency formatting //
						/////////////////////////

						var bCurrSymbAtFront = false;
						var strCurrSymb      = '';
						var strDecSymb       = '';
						var strThouSymb      = '';

						function getCurrencyInfoFromTopPrize()
						{
							var topPrize               = convertedPrizeValues[0];
							var strPrizeAsDigits       = topPrize.replace(new RegExp('[^0-9]', 'g'), '');
							var iPosFirstDigit         = topPrize.indexOf(strPrizeAsDigits[0]);
							var iPosLastDigit          = topPrize.lastIndexOf(strPrizeAsDigits.substr(-1));
							bCurrSymbAtFront           = (iPosFirstDigit != 0);
							strCurrSymb 	           = (bCurrSymbAtFront) ? topPrize.substr(0,iPosFirstDigit) : topPrize.substr(iPosLastDigit+1);
							var strPrizeNoCurrency     = topPrize.replace(new RegExp('[' + strCurrSymb + ']', 'g'), '');
							var strPrizeNoDigitsOrCurr = strPrizeNoCurrency.replace(new RegExp('[0-9]', 'g'), '');
							strDecSymb                 = strPrizeNoDigitsOrCurr.substr(-1);
							strThouSymb                = (strPrizeNoDigitsOrCurr.length > 1) ? strPrizeNoDigitsOrCurr[0] : strThouSymb;
						}

						function getPrizeInCents(AA_strPrize)
						{
							return parseInt(AA_strPrize.replace(new RegExp('[^0-9]', 'g'), ''), 10);
						}

						function getCentsInCurr(AA_iPrize)
						{
							var strValue = AA_iPrize.toString();

							strValue = (strValue.length < 3) ? ('00' + strValue).substr(-3) : strValue;
							strValue = strValue.substr(0,strValue.length-2) + strDecSymb + strValue.substr(-2);
							strValue = (strValue.length > 6) ? strValue.substr(0,strValue.length-6) + strThouSymb + strValue.substr(-6) : strValue;
							strValue = (bCurrSymbAtFront) ? strCurrSymb + strValue : strValue + strCurrSymb;

							return strValue;
						}

						getCurrencyInfoFromTopPrize();

						///////////////
						// UI Config //
						///////////////
						
						const colourBlack   = '#000000';
						const colourBlue    = '#99ccff';
						const colourCyan    = '#ccffff';
						const colourFuschia = '#ff99cc';
						const colourGold    = '#ffdd77';
						const colourGreen   = '#99ff99';
						const colourLemon   = '#ffff99';
						const colourLilac   = '#ccccff';
						const colourLime    = '#ccff99';
						const colourNavy    = '#0000ff';						
						const colourOrange  = '#ffaa55';
						const colourPink    = '#ffcccc';
						const colourPurple  = '#cc99ff';
						const colourRed     = '#ff9999';						
						const colourScarlet = '#ff0000';
						const colourWhite   = '#ffffff';
						const colourYellow  = '#ffff00';

						const specialBoxColours  = [colourNavy, colourScarlet];
						const specialTextColours = [colourYellow, colourYellow];
						const prizeColours       = [colourRed, colourOrange, colourGold, colourLemon, colourLime, colourGreen, colourCyan, colourBlue, colourLilac, colourPurple, colourFuschia, colourPink];

						var canvasIdStr   = '';
						var elementStr    = '';
						var boxColourStr  = '';
						var textColourStr = '';
						var textStr       = '';

						var r = [];

						function showBox(A_strCanvasId, A_strCanvasElement, A_iBoxCells, A_strBoxColour, A_strTextColour, A_strText)
						{
							const boxWidthStd  = 30;
							const boxHeightStd = 24;
							const boxMargin    = 1;

							var canvasCtxStr = 'canvasContext' + A_strCanvasElement;
							var boxWidth     = ((A_iBoxCells == cellTypes.iQuad) ? 1 : 2) * boxWidthStd;
							var canvasWidth  = boxWidth + 2 * boxMargin;
							var boxHeight    = ((A_iBoxCells == cellTypes.iSingle) ? 2 : 1) * boxHeightStd;
							var canvasHeight = boxHeight + 2 * boxMargin;

							r.push('<canvas id="' + A_strCanvasId + '" width="' + canvasWidth.toString() + '" height="' + canvasHeight.toString() + '"></canvas>');
							r.push('<script>');
							r.push('var ' + A_strCanvasElement + ' = document.getElementById("' + A_strCanvasId + '");');
							r.push('var ' + canvasCtxStr + ' = ' + A_strCanvasElement + '.getContext("2d");');
							r.push(canvasCtxStr + '.font = "bold 14px Arial";');
							r.push(canvasCtxStr + '.textAlign = "center";');
							r.push(canvasCtxStr + '.textBaseline = "middle";');
							r.push(canvasCtxStr + '.strokeRect(' + (boxMargin + 0.5).toString() + ', ' + (boxMargin + 0.5).toString() + ', ' + boxWidth.toString() + ', ' + boxHeight.toString() + ');');
							r.push(canvasCtxStr + '.fillStyle = "' + A_strBoxColour + '";');
							r.push(canvasCtxStr + '.fillRect(' + (boxMargin + 1.5).toString() + ', ' + (boxMargin + 1.5).toString() + ', ' + (boxWidth - 2).toString() + ', ' + (boxHeight - 2).toString() + ');');
							r.push(canvasCtxStr + '.fillStyle = "' + A_strTextColour + '";');
							r.push(canvasCtxStr + '.fillText("' + A_strText + '", ' + (boxWidth / 2 + boxMargin).toString() + ', ' + (boxHeight / 2 + 3).toString() + ');');

							r.push('</script>');
						}

						///////////////////////
						// Prize Symbols Key //
						///////////////////////

						var prizeIndex  = -1;
						var symbPrize   = '';
						var symbDesc    = '';
						var symbSpecial = '';

						r.push('<div style="float:left; margin-right:50px">');
						r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
						r.push('<tr class="tablehead">');
						r.push('<td colspan="4" style="padding-bottom:10px">' + getTranslationByName("titlePrizeSymbolsKey", translations) + '</td>');
						r.push('</tr>');
						r.push('<tr class="tablehead">');
						r.push('<td>' + getTranslationByName("keySymbol", translations) + '</td>');
						r.push('<td style="padding-left:10px; padding-right:30px">' + getTranslationByName("keyDescription", translations) + '</td>');
						r.push('<td>' + getTranslationByName("keySymbol", translations) + '</td>');
						r.push('<td style="padding-left:10px">' + getTranslationByName("keyDescription", translations) + '</td>');
						r.push('</tr>');

						for (var rowIndex = 0; rowIndex < prizeSymbs.length / 2; rowIndex++)
						{
							r.push('<tr class="tablebody">');

							for (var colIndex = 0; colIndex < 2; colIndex++)
							{
								prizeIndex   = colIndex * prizeSymbs.length / 2 + rowIndex;
								symbPrize    = prizeSymbs[prizeIndex];
								canvasIdStr  = 'cvsKeySymb' + symbPrize;
								elementStr   = 'eleKeySymb' + symbPrize;
								boxColourStr = prizeColours[prizeIndex];
								symbDesc     = 'symb' + symbPrize;

								r.push('<td align="center">');

								showBox(canvasIdStr, elementStr, cellTypes.iQuad, boxColourStr, colourBlack, symbPrize);

								r.push('</td>');
								r.push('<td style="padding-left:10px">' + getTranslationByName(symbDesc, translations) + '</td>');
							}

							r.push('</tr>');
						}

						r.push('</table>');
						r.push('</div>');

						/////////////////////////
						// Special Symbols Key //
						/////////////////////////

						r.push('<div style="float:left">');
						r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
						r.push('<td colspan="2" style="padding-bottom:10px">' + getTranslationByName("titleSpecialSymbolsKey", translations) + '</td>');
						r.push('</tr>');
						r.push('<tr class="tablehead">');
						r.push('<td>' + getTranslationByName("keySymbol", translations) + '</td>');
						r.push('<td style="padding-left:10px">' + getTranslationByName("keyDescription", translations) + '</td>');
						r.push('</tr>');

						for (var specialIndex = 0; specialIndex < specialSymbs.length; specialIndex++)
						{
							symbSpecial   = specialSymbs[specialIndex];
							canvasIdStr   = 'cvsKeySymb' + symbSpecial;
							elementStr    = 'eleKeySymb' + symbSpecial;
							boxColourStr  = specialBoxColours[specialIndex];
							textColourStr = specialTextColours[specialIndex];
							symbDesc      = 'symb' + symbSpecial;

							r.push('<tr class="tablebody">');
							r.push('<td align="center">');

							showBox(canvasIdStr, elementStr, cellTypes.iQuad, boxColourStr, textColourStr, symbSpecial);

							r.push('</td>');
							r.push('<td style="padding-left:10px">' + getTranslationByName(symbDesc, translations) + '</td>');
							r.push('</tr>');
						}

						r.push('</table>');
						r.push('</div>');

						///////////
						// Grids //
						///////////

						const gridColQty = 3;
						const gridRowQty = 3;

						var cellSections = 0;
						var gridCell     = 0;
						var gridSubTotal = 0;
						var gridWin      = 0;
						var isMainGrid   = false;
						var isPrizeSymb  = false;
						var prizeSymb    = '';
						var sectionCols  = 0;
						var sectionIndex = 0;
						var sectionRows  = 0;
						var winPrize     = 0;						

						r.push('<div style="clear:both">');

						for (var gridIndex = 0; gridIndex < arrGrids.length; gridIndex++)
						{
							isMainGrid   = (gridIndex == 0);
							gridStr      = (isMainGrid) ? getTranslationByName("mainGrid", translations) : (getTranslationByName("bonusGrid", translations) + ' ' + gridIndex.toString());
							gridSubTotal = 0;

							r.push('<p><br>' + gridStr.toUpperCase() + '</p>');
							r.push('<div style="float:left; margin-right:150px">');
							r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');

							for (var gridRowIndex = 0; gridRowIndex < gridRowQty; gridRowIndex++)
							{
								r.push('<tr class="tablebody">');

								for (var gridColIndex = 0; gridColIndex < gridColQty; gridColIndex++)
								{
									gridCell     = gridRowIndex * gridColQty + gridColIndex;
									cellSections = arrGrids[gridIndex].aoGridCells[gridCell].aoSplitCells.length;
									sectionRows  = (cellSections == cellTypes.iSingle) ? 1 : 2;
									sectionCols  = (cellSections == cellTypes.iQuad) ? 2 : 1;

									r.push('<td align="center">');
									r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');

									for (var sectionRowIndex = 0; sectionRowIndex < sectionRows; sectionRowIndex++)
									{
										r.push('<tr class="tablebody">');

										for (var sectionColIndex = 0; sectionColIndex < sectionCols; sectionColIndex++)
										{
											sectionIndex  = sectionRowIndex * sectionCols + sectionColIndex;
											prizeSymb     = arrGrids[gridIndex].aoGridCells[gridCell].aoSplitCells[sectionIndex].sPrize;
											canvasIdStr   = 'cvsCellSection' + gridIndex.toString() + '_' + gridCell.toString() + '_' + sectionIndex.toString();
											elementStr    = 'eleCellSection' + gridIndex.toString() + '_' + gridCell.toString() + '_' + sectionIndex.toString();
											isPrizeSymb   = (prizeSymbs.indexOf(prizeSymb) != -1);
											boxColourStr  = (isPrizeSymb) ? prizeColours[prizeSymbs.indexOf(prizeSymb)] : specialBoxColours[specialSymbs.indexOf(prizeSymb)];
											textColourStr = (isPrizeSymb) ? colourBlack : specialTextColours[specialSymbs.indexOf(prizeSymb)];

											r.push('<td align="center">');

											showBox(canvasIdStr, elementStr, cellSections, boxColourStr, textColourStr, prizeSymb);

											r.push('</td>');
										}

										r.push('</tr>');
									}

									r.push('</table>');
									r.push('</td>');
								}

								r.push('</tr>');
							}

							r.push('</table>');
							r.push('</div>');

							r.push('<div style="float:left">');
							r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');

							for (var prizeIndex = 0; prizeIndex < arrGrids[gridIndex].aoPrizes.length; prizeIndex++)
							{
								canvasIdStr = 'cvsGridWinQty' + gridIndex.toString() + '_' + prizeIndex.toString();
								elementStr  = 'eleGridWinQty' + gridIndex.toString() + '_' + prizeIndex.toString();
								textStr     = arrGrids[gridIndex].aoPrizes[prizeIndex].iPrizeQty.toString();

								r.push('<tr class="tablebody">');
								r.push('<td>' + getTranslationByName("collects", translations) + '</td>');
								r.push('<td align="center">');

								showBox(canvasIdStr, elementStr, cellTypes.iQuad, colourLime, colourBlack, textStr);

								r.push('</td>');
								r.push('<td>x</td>');

								canvasIdStr  = 'cvsGridWinSymb' +  + gridIndex.toString() + '_' + prizeIndex.toString();
								elementStr   = 'eleGridWinSymb' +  + gridIndex.toString() + '_' + prizeIndex.toString();
								prizeSymb    = arrGrids[gridIndex].aoPrizes[prizeIndex].sPrizeSymb;
								boxColourStr = prizeColours[prizeSymbs.indexOf(prizeSymb)];
								winPrize     = convertedPrizeValues[getPrizeNameIndex(prizeNames, prizeSymb + textStr)];

								r.push('<td align="center">');

								showBox(canvasIdStr, elementStr, cellTypes.iQuad, boxColourStr, colourBlack, prizeSymb);

								r.push('</td>');
								r.push('<td>= ' + winPrize + '</td>');
								r.push('</tr>');

								gridSubTotal += getPrizeInCents(winPrize);
							}

							r.push('</table>');
							r.push('<br><table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
							r.push('<tr class="tablebody">');
							r.push('<td>' + gridStr + ' ' + getTranslationByName("gridTotalWin", translations) + ' = ' + getCentsInCurr(gridSubTotal) + '</td>');

							if (!isMainGrid)
							{
								canvasIdStr = 'cvsGridWin' + gridIndex.toString();
								elementStr  = 'eleGridWin' + gridIndex.toString();
								textStr     = 'x' + arrGrids[gridIndex].iMulti.toString();
								gridWin     = getCentsInCurr(gridSubTotal * arrGrids[gridIndex].iMulti);

								r.push('<td align="center">');

								showBox(canvasIdStr, elementStr, cellTypes.iQuad, colourScarlet, colourYellow, textStr);

								r.push('</td>');
								r.push('<td>= ' + gridWin + '</td>');
							}

							r.push('</tr>');
							r.push('</table>');

							if (isMainGrid)
							{
								canvasIdStr = 'cvsMGBonus';
								elementStr  = 'eleMGBonus';

								r.push('<br><table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
								r.push('<tr class="tablebody">');
								r.push('<td align="center">');

								showBox(canvasIdStr, elementStr, cellTypes.iQuad, colourNavy, colourYellow, specialSymbs[0]);

								r.push('</td>');
								r.push('<td> : ' + getTranslationByName("collects", translations) + ' ' + arrGrids[gridIndex].iBonus.toString() + ' / ' + bonusQty.toString() + '</td>');

								if (arrGrids[gridIndex].iBonus == bonusQty)
								{
									r.push('<td> : ' + getTranslationByName("winTriggers", translations) + ' ' + getTranslationByName("bonusGame", translations) + '</td>');
								}

								r.push('</tr>');
								r.push('</table>');
							}

							r.push('</div>');
							r.push('<div style="clear:both">');
						}

						r.push('<p>&nbsp;</p>');

						////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						// DEBUG OUTPUT TABLE
						////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						if (debugFlag)
						{
							//////////////////////////////////////
							// DEBUG TABLE
							//////////////////////////////////////
							r.push('<table border="0" cellpadding="2" cellspacing="1" width="100%" class="gameDetailsTable" style="table-layout:fixed">');
							for (var idx = 0; idx < debugFeed.length; idx++)
 							{
								if (debugFeed[idx] == "")
									continue;
								r.push('<tr>');
 								r.push('<td class="tablebody">');
								r.push(debugFeed[idx]);
 								r.push('</td>');
	 							r.push('</tr>');
							}
							r.push('</table>');
						}

						return r.join('');
					}

					// Input: A list of Price Points and the available Prize Structures for the game as well as the wagered price point
					// Output: A string of the specific prize structure for the wagered price point
					function retrievePrizeTable(pricePoints, prizeStructures, wageredPricePoint)
					{
						var pricePointList = pricePoints.split(",");
						var prizeStructStrings = prizeStructures.split("|");
						
						for (var i = 0; i < pricePoints.length; ++i)
						{
							if (wageredPricePoint == pricePointList[i])
							{
								return prizeStructStrings[i];
							}
						}
						
						return "";
					}

					// Input: Json document string containing 'scenario' at root level.
					// Output: Scenario value.
					function getScenario(jsonContext)
					{
						// Parse json and retrieve scenario string.
						var jsObj = JSON.parse(jsonContext);
						var scenario = jsObj.scenario;

						// Trim null from scenario string.
						scenario = scenario.replace(/\0/g, '');

						return scenario;
					}
					
					// Input: Json document string containing 'amount' at root level.
					// Output: Price Point value.
					function getPricePoint(jsonContext)
					{
						// Parse json and retrieve price point amount
						var jsObj = JSON.parse(jsonContext);
						var pricePoint = jsObj.amount;

						return pricePoint;
					}

					// Input: "A,B,C,D,..." and "A"
					// Output: index number
					function getPrizeNameIndex(prizeNames, currPrize)
					{
						for(var i = 0; i < prizeNames.length; i++)
						{
							if (prizeNames[i] == currPrize)
							{
								return i;
							}
						}
					}

					////////////////////////////////////////////////////////////////////////////////////////
					function registerDebugText(debugText)
					{
						debugFeed.push(debugText);
					}
					/////////////////////////////////////////////////////////////////////////////////////////

					function getTranslationByName(keyName, translationNodeSet)
					{
						var index = 1;
						while(index < translationNodeSet.item(0).getChildNodes().getLength())
						{
							var childNode = translationNodeSet.item(0).getChildNodes().item(index);
							
							if (childNode.name == "phrase" && childNode.getAttribute("key") == keyName)
							{
								//registerDebugText("Child Node: " + childNode.name);
								return childNode.getAttribute("value");
							}
							
							index += 1;
						}
					}

					// Grab Wager Type
					// @param jsonContext String JSON results to parse and display.
					// @param translation Set of Translations for the game.
					function getType(jsonContext, translations)
					{
						// Parse json and retrieve wagerType string.
						var jsObj = JSON.parse(jsonContext);
						var wagerType = jsObj.wagerType;

						return getTranslationByName(wagerType, translations);
					}
					]]>
				</lxslt:script>
			</lxslt:component>

			<x:template match="root" mode="last">
				<table border="0" cellpadding="1" cellspacing="1" width="100%" class="gameDetailsTable">
					<tr>
						<td valign="top" class="subheader">
							<x:value-of select="//translation/phrase[@key='totalWager']/@value" />
							<x:value-of select="': '" />
							<x:call-template name="Utils.ApplyConversionByLocale">
								<x:with-param name="multi" select="/output/denom/percredit" />
								<x:with-param name="value" select="//ResultData/WagerOutcome[@name='Game.Total']/@amount" />
								<x:with-param name="code" select="/output/denom/currencycode" />
								<x:with-param name="locale" select="//translation/@language" />
							</x:call-template>
						</td>
					</tr>
					<tr>
						<td valign="top" class="subheader">
							<x:value-of select="//translation/phrase[@key='totalWins']/@value" />
							<x:value-of select="': '" />
							<x:call-template name="Utils.ApplyConversionByLocale">
								<x:with-param name="multi" select="/output/denom/percredit" />
								<x:with-param name="value" select="//ResultData/PrizeOutcome[@name='Game.Total']/@totalPay" />
								<x:with-param name="code" select="/output/denom/currencycode" />
								<x:with-param name="locale" select="//translation/@language" />
							</x:call-template>
						</td>
					</tr>
				</table>
			</x:template>

			<!-- TEMPLATE Match: digested/game -->
			<x:template match="//Outcome">
				<x:if test="OutcomeDetail/Stage = 'Scenario'">
					<x:call-template name="Scenario.Detail" />
				</x:if>
			</x:template>

			<!-- TEMPLATE Name: Scenario.Detail (base game) -->
			<x:template name="Scenario.Detail">
				<x:variable name="odeResponseJson" select="string(//ResultData/JSONOutcome[@name='ODEResponse']/text())" />
				<x:variable name="translations" select="lxslt:nodeset(//translation)" />
				<x:variable name="wageredPricePoint" select="string(//ResultData/WagerOutcome[@name='Game.Total']/@amount)" />
				<x:variable name="prizeTable" select="lxslt:nodeset(//lottery)" />

				<table border="0" cellpadding="0" cellspacing="0" width="100%" class="gameDetailsTable">
					<tr>
						<td class="tablebold" background="">
							<x:value-of select="//translation/phrase[@key='wagerType']/@value" />
							<x:value-of select="': '" />
							<x:value-of select="my-ext:getType($odeResponseJson, $translations)" disable-output-escaping="yes" />
						</td>
					</tr>
					<tr>
						<td class="tablebold" background="">
							<x:value-of select="//translation/phrase[@key='transactionId']/@value" />
							<x:value-of select="': '" />
							<x:value-of select="OutcomeDetail/RngTxnId" />
						</td>
					</tr>
				</table>
				<br />			
				
				<x:variable name="convertedPrizeValues">
					<x:apply-templates select="//lottery/prizetable/prize" mode="PrizeValue"/>
				</x:variable>

				<x:variable name="prizeNames">
					<x:apply-templates select="//lottery/prizetable/description" mode="PrizeDescriptions"/>
				</x:variable>


				<x:value-of select="my-ext:formatJson($odeResponseJson, $translations, $prizeTable, string($convertedPrizeValues), string($prizeNames))" disable-output-escaping="yes" />
			</x:template>

			<x:template match="prize" mode="PrizeValue">
					<x:text>|</x:text>
					<x:call-template name="Utils.ApplyConversionByLocale">
						<x:with-param name="multi" select="/output/denom/percredit" />
					<x:with-param name="value" select="text()" />
						<x:with-param name="code" select="/output/denom/currencycode" />
						<x:with-param name="locale" select="//translation/@language" />
					</x:call-template>
			</x:template>
			<x:template match="description" mode="PrizeDescriptions">
				<x:text>,</x:text>
				<x:value-of select="text()" />
			</x:template>

			<x:template match="text()" />
		</x:stylesheet>
	</xsl:template>

	<xsl:template name="TemplatesForResultXSL">
		<x:template match="@aClickCount">
			<clickcount>
				<x:value-of select="." />
			</clickcount>
		</x:template>
		<x:template match="*|@*|text()">
			<x:apply-templates />
		</x:template>
	</xsl:template>
</xsl:stylesheet>
