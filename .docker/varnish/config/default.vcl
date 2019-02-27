vcl 4.0;

import std;

backend default {
    .host = "nginx";
    .port = "9091";
    .first_byte_timeout = 300s;
}

sub vcl_recv {
    unset req.http.Forwarded;

    if (req.http.X-Forwarded-Proto == "https" ) {
        set req.http.X-Forwarded-Port = "443";#
    } else {
        set req.http.X-Forwarded-Port = "80";
    }

    if (req.url ~ "/_wdt") {
        return (pass);
    }

    # Set initial grace period usage status
    set req.http.grace = "none";

    # collect all cookies
    std.collect(req.http.Cookie);

    # Compression filter. See https://www.varnish-cache.org/trac/wiki/FAQ/Compression
    if (req.http.Accept-Encoding) {
        if (req.url ~ "\.(jpg|jpeg|png|gif|gz|tgz|bz2|tbz|mp3|ogg|swf|flv)$") {
            # No point in compressing these (these filetypes are already compressed by nature)
            unset req.http.Accept-Encoding;
        } elsif (req.http.Accept-Encoding ~ "gzip") {
            set req.http.Accept-Encoding = "gzip";
        } elsif (req.http.Accept-Encoding ~ "deflate" && req.http.user-agent !~ "MSIE") {
            set req.http.Accept-Encoding = "deflate";
        } else {
            # unkown algorithm
            unset req.http.Accept-Encoding;
        }
    }

    # Normalize the url
    #  * query arguments order
    #  * leading HTTP scheme and domain
    #  * remove the Google Analytics added parameters
    #  * Strip hash
    #  * Strip a trailing ?
    set req.url = std.querysort(req.url);
    set req.url = regsub(req.url, "^http[s]?://", "");
    set req.url = regsuball(req.url, "&(utm_source|utm_medium|utm_campaign|utm_content|gclid|cx|ie|cof|siteurl)=([A-z0-9_\-\.%25]+)", "");
    set req.url = regsuball(req.url, "\?(utm_source|utm_medium|utm_campaign|utm_content|gclid|cx|ie|cof|siteurl)=([A-z0-9_\-\.%25]+)", "?");
    set req.url = regsub(req.url, "\#.*$", "");
    set req.url = regsub(req.url, "\?&", "?");
    set req.url = regsub(req.url, "\?$", "");


    set req.http.Cookie = regsuball(req.http.Cookie, "has_js=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "__utm.=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "_ga=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "_gat=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "utmctr=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "utmcmd.=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "utmccn.=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "__gads=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "__qc.=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "__atuv.=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "^;\s*", "");
    if (req.http.cookie ~ "^\s*$") {
        unset req.http.cookie;
    }

    # Static files : no cookie, no https, in cache
    if (req.url ~ "^[^?]*\.(7z|avi|bmp|bz2|css|csv|doc|docx|eot|flac|flv|gif|gz|ico|jpeg|jpg|js|less|mka|mkv|mov|mp3|mp4|mpeg|mpg|odt|otf|ogg|ogm|opus|pdf|png|ppt|pptx|rar|rtf|svg|svgz|swf|tar|tbz|tgz|ttf|txz|wav|webm|webp|woff|woff2|xls|xlsx|xml|xz|zip)(\?.*)?$") {
        unset req.http.Https;
        unset req.http.X-Forwarded-Proto;
        unset req.http.Cookie;
        return (hash);
    }

    # we do not cache the app
    return (hash);

    // Add a Surrogate-Capability header to announce ESI support.
    // set req.http.Surrogate-Capability = "abc=ESI/1.0";
}

sub vcl_hash {
    # To make sure http users don't see ssl warning
    if (req.http.X-Forwarded-Proto) {
        hash_data(req.http.X-Forwarded-Proto);
    }
}

sub vcl_backend_response {
    # Large static files are delivered directly to the end-user without cache
    if (bereq.url ~ "^[^?]*\.(7z|avi|bz2|flac|flv|gz|mka|mkv|mov|mp3|mp4|mpeg|mpg|ogg|ogm|opus|rar|tar|tgz|tbz|txz|wav|webm|xz|zip)(\?.*)?$") {
        unset beresp.http.set-cookie;
        set beresp.do_stream = true;
        set beresp.uncacheable = true;
    }

//    if (bereq.url ~ "\.js$" || beresp.http.content-type ~ "text") {
//        set beresp.do_gzip = true;
//    }

    # cache only successfully responses and 404s
//    if (beresp.status != 200 && beresp.status != 404) {
//        set beresp.ttl = 0s;
//        set beresp.uncacheable = true;
//        return (deliver);
//    } elsif (beresp.http.Cache-Control ~ "private") {
//        set beresp.uncacheable = true;
//        set beresp.ttl = 86400s;
//        return (deliver);
//    }

    # validate if we need to cache it and prevent from setting cookie
//    if (beresp.ttl > 0s && (bereq.method == "GET" || bereq.method == "HEAD")) {
//        unset beresp.http.set-cookie;
//    }

    set beresp.grace = 3d;

    # If page is not cacheable then bypass varnish for 2 minutes as Hit-For-Pass
//   if (beresp.ttl <= 0s ||
//        beresp.http.Surrogate-control ~ "no-store" ||
//        (!beresp.http.Surrogate-Control && beresp.http.Vary == "*")) {
//        # Mark as Hit-For-Pass for the next 2 minutes
//        set beresp.ttl = 120s;
//        set beresp.uncacheable = true;
//    }

    return (deliver);
}

sub vcl_deliver {
    set resp.http.X-Front = server.hostname;

    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
    } else {
        set resp.http.X-Cache = "MISS";
    }
    set resp.http.X-Cache-Hits = obj.hits;
}

