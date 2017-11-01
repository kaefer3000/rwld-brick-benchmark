#!/usr/bin/awk -f
# Assumes sorted input
{
    count[NR] = $1;
    x += $1;
    y += $1^2;
}
END {
    printf "Median: "
    if (NR % 2) {
        printf count[(NR + 1) / 2] ;
    } else {
        printf (count[(NR / 2)] + count[(NR / 2) + 1]) / 2.0 ;
    }
    print " ;","Average:", x/NR, ";", "StdDev:", sqrt(y/NR - (x/NR)^2)
}
