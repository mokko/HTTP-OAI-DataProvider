<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	version="1.0" xmlns:mpx="http://www.mpx.org/mpx"
	xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/"
	xmlns:dc="http://purl.org/dc/elements/1.1/"
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd"
	exclude-result-prefixes="mpx">

	<!--
		Dublin Core comes with a semantic definition of these terms, current
		version at http://dublincore.org/documents/dces
		How do I know how  oai_dc interprets these terms? I use the quoted
		definitions. Will copy them here for conveniance.
	-->

	<xsl:template match="/">
		<oai_dc:dc>
			<!--
				dc:title
				A name given to the resource. Typically, a Title will be a name
				by which the resource is formally known.
				take mpx:titel if any; otherwise mpx:sachbegriff
			-->
			<xsl:choose>
				<xsl:when
					test="/mpx:museumPlusExport/mpx:sammlungsobjekt/mpx:titel">
					<xsl:for-each
						select="/mpx:museumPlusExport/mpx:sammlungsobjekt/mpx:titel">
						<dc:title>
							<xsl:value-of select="." />
						</dc:title>
					</xsl:for-each>

				</xsl:when>
				<xsl:when
					test="/mpx:museumPlusExport/mpx:sammlungsobjekt/mpx:sachbegriff">
					<xsl:for-each
						select="/mpx:museumPlusExport/mpx:sammlungsobjekt/mpx:sachbegriff">
						<dc:title>
							<xsl:value-of select="." />
						</dc:title>
					</xsl:for-each>
				</xsl:when>
			</xsl:choose>
			<!--
				dc:creator
				An entity primarily responsible for making the resource.
				Examples of a Creator include a person, an organization,
				or a service. Typically, the name of a Creator should be
				used to indicate the entity.

				Hersteller, Produzent. (Interpret ist nicht unbedingt ein Akteur,
				der primär für die Herstellung verantwortlich war.)
			-->
			<xsl:for-each
				select="/mpx:museumPlusExport/mpx:sammlungsobjekt/mpx:personKörperschaftRef[@funktion = 'Hersteller' or @funktion = 'Produzent']">
				<dc:creator>
					<xsl:value-of select="." />
				</dc:creator>
			</xsl:for-each>
			<!--
				dc:subject
				The topic of the resource. Typically, the subject will be
				represented using keywords, key phrases, or classification
				codes. Recommended best practice is to use a controlled
				vocabulary. To describe the spatial or temporal topic of the
				resource, use the Coverage element.
			-->
			<xsl:for-each
				select="/mpx:museumPlusExport/mpx:sammlungsobjekt/mpx:sachbegriff">
				<dc:subject>
					<xsl:value-of select="." />
				</dc:subject>
			</xsl:for-each>
			<!--
				dc:description
				An account of the resource. Description may include but is not
				limited to: an abstract, a table of contents, a graphical
				representation, or a free-text account of the resource.
			-->
			<xsl:for-each
				select="/mpx:museumPlusExport/mpx:sammlungsobjekt/mpx:langeBeschreibung|
                /mpx:museumPlusExport/mpx:sammlungsobjekt/mpx:sammlungsobjekt/mpx:kurzeBeschreibung|
                /mpx:museumPlusExport/mpx:sammlungsobjekt/mpx:inhalt|
                /mpx:museumPlusExport/mpx:sammlungsobjekt/mpx:besetzung">
				<dc:description>
					<xsl:value-of select="." />
				</dc:description>
			</xsl:for-each>
			<!-- publisher -->

			<!-- contributor -->
			<xsl:for-each
				select="/mpx:museumPlusExport/mpx:sammlungsobjekt/mpx:personKörperschaftRef[@funktion = 'Hersteller' or @funktion = 'Interpret']">
				<dc:contributor>
					<xsl:value-of select="." />
				</dc:contributor>
			</xsl:for-each>

			<!--
				dc:date
				A point or period of time associated with an event in the
				lifecycle of the resource. Date may be used to express
				temporal information at any level of granularity.
				Recommended best practice is to use an encoding scheme,
				such as the W3CDTF profile of ISO 8601 [W3CDTF].
			-->
			<xsl:for-each
				select="/mpx:museumPlusExport/mpx:sammlungsobjekt/mpx:datierung">
				<dc:date>
					<xsl:value-of select="." />
				</dc:date>
			</xsl:for-each>


			<!--
				dc:type
				The nature or genre of the resource. Recommended best practice
				is to use a controlled vocabulary such as the DCMI Type Vocabulary
				[DCMITYPE]. To describe the file format, physical medium, or
				dimensions of the resource, use the Format element.
			-->
			<xsl:for-each
				select="/mpx:museumPlusExport/mpx:sammlungsobjekt/mpx:objekttyp">
				<dc:type>
					<xsl:value-of select="." />
				</dc:type>
			</xsl:for-each>
			<!--dc:format
				TODO. Massangabe, Formatbegriffe aus Sachbegriff etc.
			-->

			<!--dc:identifier-->
			<xsl:for-each
				select="/mpx:museumPlusExport/mpx:sammlungsobjekt/mpx:identNr|
				/mpx:museumPlusExport/mpx:sammlungsobjekt/mpx:andereNr[@art = 'Produktions-Nr.']">
				<dc:identifier>
					<xsl:value-of select="." />
				</dc:identifier>
			</xsl:for-each>
			<!--dc:source
				A related resource from which the described resource is derived.
			-->
			<dc:source>
				<xsl:value-of
					select="/mpx:museumPlusExport/mpx:sammlungsobjekt/mpx:credits" />
				<xsl:value-of select="' - '" />
				<xsl:value-of
					select="/mpx:museumPlusExport/mpx:sammlungsobjekt/mpx:verantwortlichkeit" />
			</dc:source>
			<!--
				dc:language
			-->
			<dc:language>de</dc:language>

			<!--dc:relation
				A related resource by means of a string conforming to a formal
				identification system.

				URI?
			-->
			<xsl:for-each
				select="/mpx:museumPlusExport/mpx:multimediaobjekt">
				<dc:relation>
					<xsl:choose>
						<!-- match urls -->
						<xsl:when
							test="contains (mpx:multimediaPfadangabe, '://')">
							<xsl:value-of
								select="concat(mpx:multimediaPfadangabe,'/',mpx:multimediaDateiname,'.',mpx:multimediaErweiterung)" />
						</xsl:when>
						<!-- match internal MuseumPlus paths -->
						<xsl:otherwise>
							<xsl:value-of
								select="concat(mpx:multimediaPfadangabe,'\',mpx:multimediaDateiname,'.',mpx:multimediaErweiterung)" />
						</xsl:otherwise>
					</xsl:choose>
				</dc:relation>
			</xsl:for-each>


			<!--dc:coverage
				The spatial or temporal topic of the resource, the spatial
				applicability of the resource, or the jurisdiction under which the
				resource is relevant.
			-->
			<!--
				dc:rights

				too legal, too difficult
			-->
		</oai_dc:dc>
	</xsl:template>
</xsl:stylesheet>
