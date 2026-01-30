
import XCTest
@testable import AdViews

final class VASTParserTests: XCTestCase {
    
    /// Test parsing VAST with product extensions
    func testParsingVASTWithProductExtensions() throws {
        let vastXML = """
        <VAST version="4.2">
            <Ad id="ea7f1986-95c3-42c6-b8a0-85e409ca4160" sequence="1">
                <InLine>
                    <AdSystem version="1.0">Gowit Ads</AdSystem>
                    <AdTitle>Gowit Vast Tag</AdTitle>
                    <Extensions>
                        <Extension type="product">
                            <Product>
                                <AdvertiserID>2628</AdvertiserID>
                                <Brand>Adidas</Brand>
                                <ImageURL>https://cdn.beymen.com/test.jpg</ImageURL>
                                <Name>BRMD Yeşil Pudra Kadın Sneaker</Name>
                                <PdpURL></PdpURL>
                                <Price>5250</Price>
                                <Rating>0</Rating>
                                <Sku>1657549</Sku>
                                <StockCount>0</StockCount>
                            </Product>
                        </Extension>
                    </Extensions>
                    <Creatives>
                        <Creative id="8013" sequence="1">
                            <Linear>
                                <Duration>00:00:53</Duration>
                                <MediaFiles>
                                    <MediaFile delivery="progressive" type="video/mp4" width="512" height="288">
                                        <![CDATA[https://example.com/video.mp4]]>
                                    </MediaFile>
                                </MediaFiles>
                                <VideoClicks>
                                    <ClickThrough>
                                        <![CDATA[https://test.beymen.com/tr/brand-adidas-3184]]>
                                    </ClickThrough>
                                    <ClickTracking>
                                        <![CDATA[https://beymen-stage.gowit.com/server/vast/events?type=click&ad_id=test]]>
                                    </ClickTracking>
                                </VideoClicks>
                                <TrackingEvents>
                                    <Tracking event="start">
                                        <![CDATA[https://beymen-stage.gowit.com/server/vast/events?type=video_start&ad_id=test]]>
                                    </Tracking>
                                    <Tracking event="complete">
                                        <![CDATA[https://beymen-stage.gowit.com/server/vast/events?type=video_complete&ad_id=test]]>
                                    </Tracking>
                                </TrackingEvents>
                            </Linear>
                        </Creative>
                    </Creatives>
                </InLine>
            </Ad>
        </VAST>
        """
        
        let parser = VASTParser()
        let data = vastXML.data(using: .utf8)!
        let response = try parser.parse(data: data)
        
        // Verify ad was parsed
        XCTAssertFalse(response.isEmpty)
        XCTAssertEqual(response.ads.count, 1)
        
        let ad = response.firstAd!
        XCTAssertEqual(ad.id, "ea7f1986-95c3-42c6-b8a0-85e409ca4160")
        XCTAssertNotNil(ad.inLine)
        
        let inLine = ad.inLine!
        
        // Verify product extensions were parsed
        XCTAssertEqual(inLine.extensions.count, 1)
        let product = inLine.extensions.first!
        XCTAssertEqual(product.advertiserID, "2628")
        XCTAssertEqual(product.brand, "Adidas")
        XCTAssertEqual(product.name, "BRMD Yeşil Pudra Kadın Sneaker")
        XCTAssertEqual(product.price, 5250)
        XCTAssertEqual(product.sku, "1657549")
        
        // CRITICAL: Verify creatives were also parsed correctly
        XCTAssertEqual(inLine.creatives.count, 1, "Creatives should be parsed")
        
        let creative = inLine.creatives.first!
        XCTAssertEqual(creative.id, "8013")
        XCTAssertNotNil(creative.linear, "Linear should be parsed")
        
        let linear = creative.linear!
        XCTAssertEqual(linear.duration, 53)
        XCTAssertEqual(linear.mediaFiles.count, 1, "MediaFiles should be parsed")
        
        let mediaFile = linear.mediaFiles.first!
        XCTAssertEqual(mediaFile.url, "https://example.com/video.mp4")
        XCTAssertEqual(mediaFile.type, "video/mp4")
        XCTAssertEqual(mediaFile.width, 512)
        XCTAssertEqual(mediaFile.height, 288)
        
        // Verify click through
        XCTAssertNotNil(linear.videoClicks)
        XCTAssertEqual(linear.videoClicks?.clickThrough, "https://test.beymen.com/tr/brand-adidas-3184")
        
        // Verify tracking events
        XCTAssertEqual(linear.trackingEvents.count, 2)
        
        print("✅ All parsing tests passed!")
        print("   - Products parsed: \(inLine.extensions.count)")
        print("   - Creatives parsed: \(inLine.creatives.count)")
        print("   - MediaFiles parsed: \(linear.mediaFiles.count)")
        print("   - MediaFile URL: \(mediaFile.url)")
    }
    
    /// Test parsing multiple products
    func testParsingMultipleProducts() throws {
        let vastXML = """
        <VAST version="4.2">
            <Ad id="test-ad">
                <InLine>
                    <Extensions>
                        <Extension type="product">
                            <Product>
                                <Brand>Nike</Brand>
                                <Name>Product 1</Name>
                            </Product>
                            <Product>
                                <Brand>Adidas</Brand>
                                <Name>Product 2</Name>
                            </Product>
                        </Extension>
                    </Extensions>
                    <Creatives>
                        <Creative>
                            <Linear>
                                <MediaFiles>
                                    <MediaFile type="video/mp4">https://video.mp4</MediaFile>
                                </MediaFiles>
                            </Linear>
                        </Creative>
                    </Creatives>
                </InLine>
            </Ad>
        </VAST>
        """
        
        let parser = VASTParser()
        let data = vastXML.data(using: .utf8)!
        let response = try parser.parse(data: data)
        
        let inLine = response.firstAd!.inLine!
        
        // Verify both products were parsed
        XCTAssertEqual(inLine.extensions.count, 2)
        XCTAssertEqual(inLine.extensions[0].brand, "Nike")
        XCTAssertEqual(inLine.extensions[1].brand, "Adidas")
        
        // Verify creatives still work
        XCTAssertEqual(inLine.creatives.count, 1)
        XCTAssertEqual(inLine.creatives.first?.linear?.mediaFiles.count, 1)
    }
    
    /// Test parsing VAST without extensions
    func testParsingVASTWithoutExtensions() throws {
        let vastXML = """
        <VAST version="4.2">
            <Ad id="test-ad">
                <InLine>
                    <Creatives>
                        <Creative>
                            <Linear>
                                <Duration>00:00:30</Duration>
                                <MediaFiles>
                                    <MediaFile type="video/mp4">https://video.mp4</MediaFile>
                                </MediaFiles>
                            </Linear>
                        </Creative>
                    </Creatives>
                </InLine>
            </Ad>
        </VAST>
        """
        
        let parser = VASTParser()
        let data = vastXML.data(using: .utf8)!
        let response = try parser.parse(data: data)
        
        let inLine = response.firstAd!.inLine!
        
        // Extensions should be empty but not cause issues
        XCTAssertTrue(inLine.extensions.isEmpty)
        
        // Creatives should still work fine
        XCTAssertEqual(inLine.creatives.count, 1)
        XCTAssertEqual(inLine.creatives.first?.linear?.duration, 30)
    }
}
