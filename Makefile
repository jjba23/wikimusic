# wikimusic - the free music knowledge encyclopaedia

# Copyright © Josep Bigorra <jjbigorra@gmail.com>

# wikimusic is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# wikimusic is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License
# along with wikimusic.  If not, see <https://www.gnu.org/licenses/>.

# Code:

# Constants

WIKIMUSIC_DB="wikimusic.db"
COPYRIGHT_HOLDERS="Josep Bigorra"
I18N_LOCATION="sys/i18n/locale"

# System details
GUIX_VERSION := $(shell guix --version)

.PHONY: dev server production-server fmt init-db compile-i18n new-i18n join-i18n init-i18n-nl init-i18n-en merge-i18n-nl merge-i18n-en

# Logging helpers

define wikimusic-log-info
	@printf "\n\033[1m[info] $(shell date --rfc-3339=seconds) - %s\033[0m\n" $(1)
endef

# i18n helpers

# Define a function for compiling the translation file (.po) into a machine-readable (.mo) format
# Arguments: $(1) represents the language code (e.g., "en_US", "nl_NL", etc.)
# Use msgfmt to compile the .po file into a .mo file for the specified language
# The output .mo file will be placed in the LC_MESSAGES directory under the language's folder
define wikimusic-msgfmt
	msgfmt -v -o $(I18N_LOCATION)/$(1)/LC_MESSAGES/translate.mo \
		$(I18N_LOCATION)/$(1)/LC_MESSAGES/translate.po
endef

# Define a function to initialize a new translation file from a template (.pot) for a specific language
# Arguments: $(1) represents the language code (e.g., "en_US", "nl_NL", etc.)
# Use msginit to generate a .po file from the .pot template for the specified language
# The -l option sets the language, and --no-translator means no translator is pre-filled in the .po file
# The generated .po file is placed in the LC_MESSAGES directory for the given language
define wikimusic-msginit
	mkdir -p $(I18N_LOCATION)/$(1)/LC_MESSAGES
	msginit -l $(1).UTF8 -o $(I18N_LOCATION)/$(1)/LC_MESSAGES/translate.po \
		-i $(I18N_LOCATION)/translate.pot --no-translator
endef

# Define a function to merge translation updates from the template (.pot) into an existing .po file
# Arguments: $(1) represents the language code (e.g., "en_US", "nl_NL", etc.)
# Use msgmerge to update the specified language's .po file with new translations from the template (.pot)
# The -U flag updates the .po file in place
# This ensures the .po file stays up-to-date with the latest changes in the template
define wikimusic-merge
	msgmerge -U $(I18N_LOCATION)/$(1)/LC_MESSAGES/translate.po \
		$(I18N_LOCATION)/translate.pot
endef

# Define a function to extract translatable strings from Scheme source files using xgettext
# Arguments: $(1) should be either "--join-existing" for updating template
#   or "" to start from scratch.
# Run xgettext to extract strings marked for translation from Scheme source files
define wikimusic-xgettext
	xgettext --default-domain=translate \
		--output=$(I18N_LOCATION)/translate.pot \
		--language=Scheme \
		--keyword=G_ \
		--sort-by-file \
		$(1) \
		--copyright-holder=$(COPYRIGHT_HOLDERS) \
		--package-name="wikimusic" \
		lib/wikimusic/job/*.scm \
		lib/wikimusic/*.scm \
		app/controllers/*.scm \
		app/views/*.scm \
		app/api/*.scm \
		ENTRY \
		--from-code UTF-8
endef


watchexec:
	watchexec -i "dist/**" -r -e scm,css,js -- "make server"

# Target to start a development server for wikimusic
# Use watchexec to watch for file changes and restart the server on changes
dev:
	$(call wikimusic-log-info,"starting development server for wikimusic")
	make watchexec


# Target to start the wikimusic server
# Start the server with the default configuration
server:
	$(call wikimusic-log-info,"starting wikimusic server")
	guix shell -m manifest.scm -- art work

# Target to start the wikimusic server with production configuration
production-server:
	$(call wikimusic-log-info,"starting production wikimusic server")
	guix shell -m manifest.scm -- art work -c conf/production.conf

# Target to format source code files according to the style guide
# Find all .scm files and format them using 'guix style'
fmt:
	$(call wikimusic-log-info,"formatting all Scheme files")
	find . -maxdepth 8 -name "*.scm" -type f -exec guix style -f {} \;


# Initialize a new database and enable WAL mode for higher concurrent writes to SQLite 3
init-db:
	$(call wikimusic-log-info,"initializing a new database")
	-rm -v $(WIKIMUSIC_DB) $(WIKIMUSIC_DB)-shm $(WIKIMUSIC_DB)-wal
	guix shell -m manifest.scm -- sqlite3 wikimusic.db 'PRAGMA journal_mode=WAL;'

# Compile translation files to .mo files
compile-i18n:
	$(call wikimusic-log-info,"compiling translation files")
	$(call wikimusic-msgfmt,"en_US")
	$(call wikimusic-msgfmt,"nl_NL")
	$(call wikimusic-msgfmt,"es_ES")

# Create new i18n template from source code
new-i18n:
	$(call wikimusic-log-info,"creating new i18n template from source code")
	$(call wikimusic-xgettext,"")

# Update i18n template from source code
join-i18n:
	$(call wikimusic-log-info,"updating i18n template from source code")
	$(call wikimusic-xgettext,"--join-existing")

# en_US - English language targets
init-i18n-en:
	$(call wikimusic-msginit,"en_US")
merge-i18n-en:
	$(call wikimusic-merge,"en_US")

# nl_NL - Dutch language targets
init-i18n-nl:
	$(call wikimusic-msginit,"nl_NL")
merge-i18n-nl:
	$(call wikimusic-merge,"nl_NL")

# es_ES - Spanish language targets
init-i18n-es:
	$(call wikimusic-msginit,"es_ES")
merge-i18n-es:
	$(call wikimusic-merge,"es_ES")

# Development REPL
repl:
	guix shell -m manifest.scm -- guile  \
		-L lib -L . \
		-c '((@ (ares server) run-nrepl-server))'
