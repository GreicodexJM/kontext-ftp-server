// Copyright (C) 2019-2023 Nicola Murino
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, version 3.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

//go:build nobolt
// +build nobolt

package dataprovider

import (
	"errors"

	"github.com/drakkan/sftpgo/v2/internal/version"
)

func init() {
	version.AddFeature("-bolt")
}

func initializeBoltProvider(_ string) error {
	return errors.New("bolt disabled at build time")
}
