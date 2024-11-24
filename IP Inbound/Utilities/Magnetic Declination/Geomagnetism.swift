// swiftlint:disable file_header

/*	License Statement from the NOAA
 The WMM source code is in the public domain and not licensed or
 under copyright. The information and software may be used freely
 by the public. As required by 17 U.S.C. 403, third parties producing
 copyrighted works consisting predominantly of the material produced
 by U.S. government agencies must provide notice with such work(s)
 identifying the U.S. Government material incorporated and stating
 that such material is not subject to copyright protection.*/

import Foundation
import RegexBuilder

// Add vars to convert to degrees/radians
extension FloatingPoint {
    /** Convert to degrees from radians*/
    var toDegrees: Self { return self * 180 / .pi }

    /** Convert to radians from degrees*/
    var toRadians: Self { return self * .pi / 180 }
}

/** Class to calculate magnetic declination, magnetic field strength,
 inclination etc. for any point on the earth.
 
 Adapted from the geomagc software and World Magnetic Model of the NOAA
 Satellite and Information Service, National Geophysical Data Center
 
 http://www.ngdc.noaa.gov/geomag/WMM/DoDWMM.shtml
 
 © Deep Pradhan, 2017*/
final class Geomagnetism {

    /**    The input string array which contains each line of input for the wmm.cof input file.
     *    The columns in this file are as follows:    n,    m,    gnm,    hnm,    dgnm,    dhnm*/
    private static var WMM_COF: [String] {
        let url = Bundle.main.url(forResource: "WMM", withExtension: "COF")!
        let data = try! Data(contentsOf: url) // swiftlint:disable:this force_try
        return String(data: data, encoding: .ascii)!.split(separator: .newlineSequence).map { String($0) }
    }

    /** Mean radius of IAU-66 ellipsoid, in km*/
    private static let IAU66_RADIUS:Double = 6371.2

    /** Semi-major axis of WGS-1984 ellipsoid, in km*/
    private static let WGS84_A:Double = 6378.137

    /** Semi-minor axis of WGS-1984 ellipsoid, in km*/
    private static let WGS84_B:Double = 6356.7523142

    /** The maximum number of degrees of the spherical harmonic model*/
    private static let MAX_DEG:Int = 12

    /** Geomagnetic declination (decimal degrees) [opposite of variation, positive Eastward/negative Westward]*/
    private(set) var declination = Double.nan

    /** Geomagnetic inclination/dip angle (degrees) [positive downward]*/
    private(set) var inclination = Double.nan

    /** Geomagnetic field intensity/strength (nano Teslas)*/
    private(set) var intensity = Double.nan

    /** Geomagnetic horizontal field intensity/strength (nano Teslas)*/
    private(set) var horizontalIntensity = Double.nan

    /** Geomagnetic vertical field intensity/strength (nano Teslas) [positive downward]*/
    private(set) var verticalIntensity = Double.nan

    /** Geomagnetic North South (northerly component) field intensity/strength (nano Tesla)*/
    private(set) var northIntensity = Double.nan

    /** Geomagnetic East West (easterly component) field intensity/strength (nano Teslas)*/
    private(set) var eastIntensity = Double.nan

    /** The maximum order of spherical harmonic model*/
    private var maxord:Int

    /** The Gauss coefficients of main geomagnetic model (nt)*/
    private var c:[[Double]] = Array(repeating: Array(repeating: Double.nan, count: 13), count: 13)

    /** The Gauss coefficients of secular geomagnetic model (nt/yr)*/
    private var cd:[[Double]] = Array(repeating: Array(repeating: Double.nan, count: 13), count: 13)

    /** The time adjusted geomagnetic gauss coefficients (nt)*/
    private var tc:[[Double]] = Array(repeating: Array(repeating: Double.nan, count: 13), count: 13)

    /** The theta derivative of p(n,m) (unnormalized)*/
    private var dp:[[Double]] = Array(repeating: Array(repeating: Double.nan, count: 13), count: 13)

    /** The Schmidt normalization factors*/
    private var snorm:[Double] = Array(repeating: Double.nan, count: 169)

    /** The sine of (m*spherical coordinate longitude)*/
    private var sp:[Double] = Array(repeating: Double.nan, count: 13)

    /** The cosine of (m*spherical coordinate longitude)*/
    private var cp:[Double] = Array(repeating: Double.nan, count: 13)
    private var fn:[Double] = Array(repeating: Double.nan, count: 13)
    private var fm:[Double] = Array(repeating: Double.nan, count: 13)

    /** The associated Legendre polynomials for m = 1 (unnormalized)*/
    private var pp:[Double] = Array(repeating: Double.nan, count: 13)

    private var k:[[Double]] = Array(repeating: Array(repeating: Double.nan, count: 13), count: 13)

    /** The variables otime (old time), oalt (old altitude),
     *    olat (old latitude), olon (old longitude), are used to
     *    store the values used from the previous calculation to
     *    save on calculation time if some inputs don't change*/
    private var otime:Double, oalt:Double, olat:Double, olon:Double

    /** The date in years, for the start of the valid time of the fit coefficients*/
    private var epoch:Double

    private var r = Double.nan, d = Double.nan, ca = Double.nan,
                sa = Double.nan, ct = Double.nan, st = Double.nan

    /** Initializes the instance without calculations*/
    init() {
        // Initialize constants
        maxord = Self.MAX_DEG
        sp[0] = 0
        cp[0] = 1
        snorm[0] = 1
        pp[0] = 1
        dp[0][0] = 0

        c[0][0] = 0
        cd[0][0] = 0

        epoch = Double(Self.WMM_COF[0].trimmingCharacters(in: .whitespaces).split(separator: " ")[0])!

        var tokens:[String.SubSequence], n:Int, m:Int, gnm:Double, hnm:Double, dgnm:Double, dhnm:Double

        for i in (1...Self.WMM_COF.count - 1) {
            tokens = Self.WMM_COF[i].trimmingCharacters(in: .whitespaces).split(separator: " ")
            n = Int(tokens[0])!
            m = Int(tokens[1])!
            gnm = Double(tokens[2])!
            hnm = Double(tokens[3])!
            dgnm = Double(tokens[4])!
            dhnm = Double(tokens[5])!
            if m <= n {
                c[m][n] = gnm
                cd[m][n] = dgnm
                if m != 0 {
                    c[n][m - 1] = hnm
                    cd[n][m - 1] = dhnm
                }
            }
        }
        // Convert schmidt normalized gauss coefficients to unnormalized
        snorm[0] = 1
        var flnmj:Double, j:Int
        for n in (1...maxord) {
            snorm[n] = snorm[n - 1] * Double(2 * n - 1) / Double(n)
            j = 2
            var m:Int = 0, d1:Int = 1, d2:Int = (n - m + d1) / d1
            while d2 > 0 {
                k[m][n] = Double(((n - 1) * (n - 1)) - (m * m)) / Double((2 * n - 1) * (2 * n - 3))
                if m > 0 {
                    flnmj = Double((n - m + 1) * j) / Double(n + m)
                    snorm[n + m * 13] = snorm[n + (m - 1) * 13] * sqrt(flnmj)
                    j = 1
                    c[n][m - 1] = snorm[n + m * 13] * c[n][m - 1]
                    cd[n][m - 1] = snorm[n + m * 13] * cd[n][m - 1]
                }
                c[m][n] = snorm[n + m * 13] * c[m][n]
                cd[m][n] = snorm[n + m * 13] * cd[m][n]
                d2 -= 1
                m += d1
            }
            fn[n] = Double(n + 1)
            fm[n] = Double(n)
        }
        k[1][1] = 0
        fm[0] = 0
        otime = -1000
        oalt = -1000
        olat = -1000
        olon = -1000
    }

    /** Initialise the instance and calculate for given coordinate and date
     - parameters:
     - longitude: Longitude in decimal degrees
     - latitude: Latitude in decimal degrees
     - altitude: Altitude in metres (with respect to WGS-1984 ellipsoid)
     - date: Date of the calculation*/
    convenience init(longitude:Double, latitude:Double, altitude:Double? = 0, date:Date? = Date()) {
        self.init()
        calculate(longitude: longitude, latitude: latitude, altitude: altitude!, date: date!)
    }

    /** Calculate for given coordinate and date
     - parameters:
     - longitude: Longitude in decimal degrees
     - latitude: Latitude in decimal degrees
     - altitude: Altitude in metres (with respect to WGS-1984 ellipsoid)
     - date: Date of the calculation*/
    func calculate(longitude:Double, latitude:Double, altitude:Double? = 0, date:Date? = Date()) {
        let rlon:Double = longitude.toRadians,
            rlat:Double = latitude.toRadians,
            altitudeKm:Double = altitude!.isNaN ? 0 : altitude! / 1000,
            calendar = Calendar(identifier: .gregorian),
            year:Int = calendar.component(.year, from: date!),
            yearLength:Int = calendar.range(of: .day, in: .year, for: date!)!.count,
            yearFraction:Double = Double(year)
        + Double(calendar.ordinality(of: .day, in: .year, for: date!)!)
        /* If .range(of: in: for:) returns an invalid value (observed on iOS < 11)
         use a leap year test based value for year length*/
        / Double(yearLength >= 365 ? yearLength : (year.isMultiple(of: 4) && (!year.isMultiple(of: 25) || (year.isMultiple(of: 400) && !year.isMultiple(of: 4000))) ? 366 : 365)),
        dt:Double = yearFraction - epoch,
        srlon:Double = sin(rlon),
        srlat:Double = sin(rlat),
        crlon:Double = cos(rlon),
        crlat:Double = cos(rlat),
        srlat2:Double = srlat * srlat,
        crlat2:Double = crlat * crlat,
        a2:Double = Self.WGS84_A * Self.WGS84_A,
        b2:Double = Self.WGS84_B * Self.WGS84_B,
        c2:Double = a2 - b2,
        a4:Double = a2 * a2,
        b4:Double = b2 * b2,
        c4:Double = a4 - b4

        sp[1] = srlon
        cp[1] = crlon

        // Convert from geodetic coords. to spherical coords.
        if altitudeKm != oalt || latitude != olat {
            let q:Double = sqrt(a2 - c2 * srlat2),
                q1:Double = altitudeKm * q,
                q2:Double = ((q1 + a2) / (q1 + b2)) * ((q1 + a2) / (q1 + b2)),
                r2:Double = ((altitudeKm * altitudeKm) + 2 * q1 + (a4 - c4 * srlat2) / (q * q))
            ct = srlat / sqrt(q2 * crlat2 + srlat2)
            st = sqrt(1 - (ct * ct))
            r = sqrt(r2)
            d = sqrt(a2 * crlat2 + b2 * srlat2)
            ca = (altitudeKm + d) / r
            sa = c2 * crlat * srlat / (r * d)
        }
        if longitude != olon {
            for m in (2...maxord) {
                sp[m] = sp[1] * cp[m - 1] + cp[1] * sp[m - 1]
                cp[m] = cp[1] * cp[m - 1] - sp[1] * sp[m - 1]
            }
        }
        let aor:Double = Self.IAU66_RADIUS / r
        var ar:Double = aor * aor,
            br:Double = 0, bt:Double = 0, bp:Double = 0, bpp:Double = 0,
            par:Double, parp:Double, temp1:Double, temp2:Double

        for n in (1...maxord) {
            ar *= aor
            var m:Int = 0, d3:Int = 1, d4:Int = (n + m + d3) / d3
            while d4 > 0 {

                // Compute unnormalized associated legendre polynomials and derivatives via recursion relations
                if altitudeKm != oalt || latitude != olat {
                    if n == m {
                        snorm[n + m * 13] = st * snorm[n - 1 + (m - 1) * 13]
                        dp[m][n] = st * dp[m - 1][n - 1] + ct * snorm[n - 1 + (m - 1) * 13]
                    }
                    if n == 1 && m == 0 {
                        snorm[n + m * 13] = ct * snorm[n - 1 + m * 13]
                        dp[m][n] = ct * dp[m][n - 1] - st * snorm[n - 1 + m * 13]
                    }
                    if n > 1 && n != m {
                        if m > n - 2 {
                            snorm[n - 2 + m * 13] = 0
                        }
                        if m > n - 2 {
                            dp[m][n - 2] = 0
                        }
                        snorm[n + m * 13] = ct * snorm[n - 1 + m * 13] - k[m][n] * snorm[n - 2 + m * 13]
                        dp[m][n] = ct * dp[m][n - 1] - st * snorm[n - 1 + m * 13] - k[m][n] * dp[m][n - 2]
                    }
                }

                // Time adjust the gauss coefficients
                if yearFraction != otime {
                    tc[m][n] = c[m][n] + dt * cd[m][n]

                    if m != 0 {
                        tc[n][m - 1] = c[n][m - 1] + dt * cd[n][m - 1]
                    }
                }

                // Accumulate terms of the spherical harmonic expansions
                par = ar * snorm[ n + m * 13]
                if m == 0 {
                    temp1 = tc[m][n] * cp[m]
                    temp2 = tc[m][n] * sp[m]
                }
                else {
                    temp1 = tc[m][n] * cp[m] + tc[n][m - 1] * sp[m]
                    temp2 = tc[m][n] * sp[m] - tc[n][m - 1] * cp[m]
                }

                bt -= ar * temp1 * dp[m][n]
                bp += (fm[m] * temp2 * par)
                br += (fn[n] * temp1 * par)

                // Special case: north/south geographic poles
                if st == 0 && m == 1 {
                    if n == 1 {
                        pp[n] = pp[n - 1]
                    } else {
                        pp[n] = ct * pp[n - 1] - k[m][n] * pp[n - 2]
                    }
                    parp = ar * pp[n]
                    bpp += (fm[m] * temp2 * parp)
                }
                d4 -= 1
                m += d3
            }
        }

        if st == 0 {
            bp = bpp
        } else {
            bp /= st
        }

        // Rotate magnetic vector components from spherical to geodetic coordinates
        // northIntensity must be the east-west field component
        // eastIntensity must be the north-south field component
        // verticalIntensity must be the vertical field component.
        northIntensity = -bt * ca - br * sa
        eastIntensity = bp
        verticalIntensity = bt * sa - br * ca

        // Compute declination (dec), inclination (dip) and total intensity (ti)
        horizontalIntensity = sqrt((northIntensity * northIntensity) + (eastIntensity * eastIntensity))
        intensity = sqrt((horizontalIntensity * horizontalIntensity) + (verticalIntensity * verticalIntensity))
        //	Calculate the declination.
        declination = atan2(eastIntensity, northIntensity).toDegrees
        inclination = atan2(verticalIntensity, horizontalIntensity).toDegrees

        otime = yearFraction
        oalt = altitudeKm
        olat = latitude
        olon = longitude
    }
}

// swiftlint:enable file_header
