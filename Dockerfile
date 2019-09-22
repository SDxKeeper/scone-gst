FROM iexechub/crosscompilers-scone:alpine3.10 as build


FROM iexechub/python-scone:3.7.3-alpine-3.10 as runtime

RUN echo "http://dl-cdn.alpinelinux.org/alpine/v3.10/community" >> /etc/apk/repositories \
    && apk update \
    && apk add --update-cache --no-cache libgcc \
    && apk --no-cache --update-cache add gcc gfortran python python-dev py-pip build-base wget freetype-dev libpng-dev \
    && apk add --no-cache --virtual .build-deps gcc musl-dev


RUN apk add patchelf

RUN apk add pcre libintl libjpeg-turbo libmount py3-gobject3 gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-libav

RUN apk add bash

RUN SCONE_MODE=sim pip install attrdict python-gnupg web3

RUN cp /usr/bin/python3.7 /usr/bin/python3

# copy scone-cli tools from cross-compiler container
COPY --from=build /opt/scone/etc /opt/scone/etc
COPY --from=build /opt/scone/bin /opt/scone/bin
COPY --from=build /opt/scone/scone-cli /opt/scone/scone-cli
COPY --from=build /usr/local/bin/scone /usr/local/bin/scone

COPY video-examples /root/video-examples

COPY signer /signer

COPY script /app

RUN SCONE_MODE=sim SCONE_HASH=1 SCONE_HEAP=2G SCONE_ALPINE=1		    \
	&& mkdir conf							    \
	&& scone fspf create fspf.pb 					    \
	&& scone fspf addr fspf.pb /  --not-protected --kernel /            \
	&& scone fspf addr fspf.pb /usr --authenticated --kernel /usr       \
	&& scone fspf addf fspf.pb /usr /usr 			            \
	&& scone fspf addr fspf.pb /bin --authenticated --kernel /bin       \
	&& scone fspf addf fspf.pb /bin /bin 			            \
	&& scone fspf addr fspf.pb /lib --authenticated --kernel /lib       \
	&& scone fspf addf fspf.pb /lib /lib 			            \
	&& scone fspf addr fspf.pb /home --authenticated --kernel /home       \
	&& scone fspf addf fspf.pb /home /home 			            \
	&& scone fspf addr fspf.pb /etc --authenticated --kernel /etc       \
	&& scone fspf addf fspf.pb /etc /etc 			            \
	&& scone fspf addr fspf.pb /sbin --authenticated --kernel /sbin     \
	&& scone fspf addf fspf.pb /sbin /sbin 			            \
	&& scone fspf addr fspf.pb /signer --authenticated --kernel /signer \
	&& scone fspf addf fspf.pb /signer /signer 			    \
	&& scone fspf addr fspf.pb /app --authenticated --kernel /app 	    \
	&& scone fspf addf fspf.pb /app /app 				    \
	&& scone fspf encrypt ./fspf.pb > /conf/keytag 			    \
	&& MRENCLAVE="$(SCONE_HASH=1 python)"			            \
	&& FSPF_TAG=$(cat conf/keytag | awk '{print $9}') 	            \
	&& FSPF_KEY=$(cat conf/keytag | awk '{print $11}')		    \
	&& FINGERPRINT="$FSPF_KEY|$FSPF_TAG|$MRENCLAVE"			    \
	&& echo $FINGERPRINT > conf/fingerprint.txt			    \
	&& printf "\n########################################################\nMREnclave: $FINGERPRINT\n########################################################\n\n"

ENV SCONE_ALPINE=1
ENV SCONE_VERSION=1
ENV SCONE_HEAP=2G
ENV ORC_CODE=backup

ENTRYPOINT python3 /app/app.py
