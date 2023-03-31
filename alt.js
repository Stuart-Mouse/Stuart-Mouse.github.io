function checkInteger(n) {
  return n.charCode == 8 || n.charCode == 0 ? null : n.charCode >= 48 && n.charCode <= 57;
}
var CustomerFormElement = (function () {
      function n() {
          var n = this;
          this.CustomerStateSelect = ko.observable(null);
          this.HiddenForTerm = ko.observable(!1);
          this.HelpText = "";
          this.Hidden = ko.observable(!1);
          this.ReadOnly = ko.observable(!1);
          this.StatePassThroughValue = "";
          this.CustomerStateSelectChanged = function (t) {
              n.StatePassThroughValue !== "" && (t = n.StatePassThroughValue);
              n.Value(t);
              n.StatePassThroughValue = "";
          };
          this.HasSalesTaxItem = function (t) {
              return n.SalesTaxIds !== null && n.SalesTaxIds.indexOf(t) > -1;
          };
          this.TermChanged = function (t) {
              var r = !1,
                  i;
              n.ElementType === FormElementTypes.Product &&
                  n.SetPricing &&
                  ((i = ko.utils.arrayFirst(n.FormElementAccounts, function (n) {
                      return n.FormTermId === t;
                  })),
                  (r = !i || !i.HasAccount));
              n.HiddenForTerm(r);
          };
          this.CustomerElementType = CustomerElementTypes.None;
          this.MaxLength = -1;
      }
      return (
          (n.prototype.AddCustomerStateSelect = function (n) {
              this.StatePassThroughValue = n;
              this.CustomerStateSelect = ko.observable(n);
              this.CustomerStateSelect.subscribe(this.CustomerStateSelectChanged);
          }),
          (n.prototype.SetOptionDisable = function (n, t) {
              t && t.Disabled() && (n.disabled = !0);
          }),
          n
      );
  })(),
  CustomerFormElementAttribute = (function () {
      function n(n) {
          var t = this;
          this.ImageSource = ko.observable(null);
          this.Value = n.Value();
          n.HasImage() &&
              (n.ImageSource() !== undefined && n.ImageSource() !== null
                  ? this.ImageSource(n.ImageSource())
                  : $.ajax({
                        url: "/FormManagement/GetImageDisplay",
                        type: "POST",
                        data: { token: this.Value },
                        dataType: "json",
                        success: function (n) {
                            n && n.array && n.token && t.ImageSource(n.array);
                        },
                    }));
      }
      return n;
  })(),
  CustomerFormElementOption = (function () {
      function n(n, t) {
          var i = this;
          this.Selected = ko.observable(!1);
          this.ReadOnly = ko.observable(!1);
          this.IsNoneOption = function () {
              return i.Value == 0 && i.Name == "None";
          };
          this.IsSoldOut = function () {
              return false;
          };
          this.FormatCurrency = function (n) {
              if (n === null) return "";
              var t = n.toFixed(2).replace("-", "").split("."),
                  i =
                      "$" +
                      $.map(t[0].split("").reverse(), function (n, t) {
                          return [t % 3 == 0 && t > 0 ? "," : "", n];
                      })
                          .reverse()
                          .join("") +
                      "." +
                      t[1];
              return n < 0 ? "-" + i : i;
          };
          this.TruncateAmount = function (n) {
              var t = n.toFixed(10);
              return t.substring(0, t.length - 8);
          };
          this.ConsumerEnteredAmountNotNegative = function () {
              return i.Price.Amount() === null ? !0 : i.Price.Amount() >= 0;
          };
          this.Name = n.Name();
          this.Value = n.Id;
          this.Price = new Money();
          this.Price.Amount(n.Price());
          this.QuantityAvailable = 10;
          this.TrackInventory = t.TrackInventory();
          this.SetPricing = t.SetPricing();
          this.HasConsumerEnteredPrice = n.ConsumerEnteredPrice();
          this.MaxPrice = n.MaxPrice();
          this.MinPrice = n.MinPrice();
          this.Quantity =
              this.QuantityAvailable !== null && this.TrackInventory
                  ? ko.observable(1).extend({
                        max: {
                            params: this.QuantityAvailable,
                            message: function (n) {
                                var t = n;
                                return t === 1 ? "Only 1 is available" : "Only " + t + " are available";
                            },
                            onlyIf: function () {
                                return i.Selected();
                            },
                        },
                    })
                  : ko.observable(1).extend({
                        max: {
                            params: 2147483647,
                            message: "The quantity entered exceeds the maximum allowed",
                            onlyIf: function () {
                                return i.Selected();
                            },
                        },
                    });
          this.SelectionText = ko.computed(function () {
              var n = i.Name;
              return i.IsNoneOption() || (i.SetPricing && !i.HasConsumerEnteredPrice && (n += " - " + i.Price.FormattedValue()), i.IsSoldOut() && (n += " Sorry, this option is no longer available")), n;
          });
          this.Total = ko.computed(function () {
              var n = new Money();
              return n.Amount(i.Price.Amount() * i.Quantity()), n;
          });
          this.Disabled = ko.computed(function () {
              return i.IsSoldOut() || i.ReadOnly();
          });
          this.ConsumerEnteredPriceEdit = ko.pureComputed({
              owner: this,
              read: function () {
                  return i.Price.Amount() !== null ? i.TruncateAmount(i.Price.Amount()) : "";
              },
              write: function (n) {
                  var r = parseFloat(n),
                      t;
                  isNaN(r) ? i.Price.Amount(0) : ((t = parseFloat(i.TruncateAmount(r))), t === i.Price.Amount() && i.Price.Amount(0.01), i.Price.Amount(t));
              },
          });
          this.Price.Amount.extend({
              min: {
                  params: this.MinPrice,
                  message: "Amount entered must be greater than or equal to " + this.FormatCurrency(this.MinPrice),
                  onlyIf: function () {
                      return i.HasConsumerEnteredPrice && i.Selected() && i.MinPrice > 0;
                  },
              },
              max: {
                  params: this.MaxPrice,
                  message: "Amount entered must be less than or equal to " + this.FormatCurrency(this.MaxPrice),
                  onlyIf: function () {
                      return i.HasConsumerEnteredPrice && i.Selected() && i.MaxPrice > 0;
                  },
              },
              validation: {
                  validator: this.ConsumerEnteredAmountNotNegative,
                  message: "Amount entered must be greater than $0.00",
                  onlyIf: function () {
                      return i.HasConsumerEnteredPrice && i.Selected();
                  },
              },
          });
      }
      return n;
  })(),
  CustomerFormElementAccount = (function () {
      function n() {
          this.Id = 0;
          this.FormElementId = 0;
          this.FormTermId = 0;
          this.FormAccountId = 0;
          this.HasAccount = !1;
      }
      return n;
  })(),
  CustomerFormResult = (function () {
      function n() {}
      return n;
  })(),
  FormDefinition = (function () {
      function n() {
          this.FormElements = ko.observableArray([]);
          this.MessageRecipients = ko.observableArray([]);
          this.SalesTaxes = ko.observableArray([]);
          this.AvailableTerms = Array();
          this.FormTerms = ko.observableArray([]);
      }
      return n;
  })(),
  FormElement = (function () {
      function n(n, t) {
          var i = this;
          this.Id = 0;
          this.Text = ko.observable("");
          this.ElementType = ko.observable(FormElementTypes.Undefined);
          this.FormElementAttributes = ko.observableArray([]);
          this.FormElementOptions = ko.observableArray([]);
          this.Required = ko.observable(!1);
          this.DisplayOrder = ko.observable(0);
          this.AllowMultiPurchase = ko.observable(!1);
          this.AllowQuantityPurchase = ko.observable(!1);
          this.SetPricing = ko.observable(!1);
          this.TrackInventory = ko.observable(!1);
          this.ShortDescription = ko.observable("");
          this.ShowShortDescription = ko.observable(!1);
          this.Moving = ko.observable(!1);
          this.ShowMoveAbove = ko.observable(!1);
          this.ShowMoveBelow = ko.observable(!1);
          this.ApplySalesTax = ko.observable("no");
          this.FormElementSalesTaxes = ko.observableArray([]);
          this.FormElementSalesTaxOptions = ko.observableArray([]);
          this.FormTerms = Array();
          this.FormElementAccounts = ko.observableArray([]);
          this.FormAccountsValid = ko.observable(!0);
          this.AddDateValueRestriction = ko.observable(!1);
          this.SignatureElementValueEntryOption = ko.observable(!1);
          this.NbsTermsHeaderDisplay = ko.observable("");
          this.FixedPriceFormElementOptions = function () {
              var n = ko.utils.arrayFilter(i.FormElementOptions(), function (n) {
                  return n.ConsumerEnteredPrice() === !1;
              });
              return ko.observableArray(n);
          };
          this.ConsumerEnteredPriceOptions = function () {
              var n = ko.utils.arrayFilter(i.FormElementOptions(), function (n) {
                  return n.ConsumerEnteredPrice() === !0;
              });
              return ko.observableArray(n);
          };
          this.AddOption = function () {
              var n = new FormElementOption(i);
              return i.FormElementOptions.push(n), n;
          };
          this.AddProductImage = function () {
              var n = new FormElementAttribute();
              n.AttributeType(FormElementAttributeTypes.ImageToken);
              i.FormElementAttributes.push(n);
          };
          this.AddShortDescription = function () {
              i.ShowShortDescription(!0);
          };
          this.AttributesAndOptionsSubscription = function (n) {
              var r, t;
              i.FormElementAttributes([]);
              i.FormElementOptions([]);
              r = +n;
              r === FormElementTypes.SingleLineText && ((t = new FormElementAttribute()), t.AttributeType(FormElementAttributeTypes.FormatType), t.Value("1"), i.FormElementAttributes.push(t));
          };
          this.RemoveOption = function (n) {
              n.Deleted(!0);
              i.FormElementOptions.remove(n);
              n.Id > 0 && i.DeletedOptions.push(n.Id);
          };
          this.SetPricingChanged = function () {
              return (
                  i.FormElementOptions().forEach(function (n) {
                      n.Price(0);
                  }),
                  i.SetPricing() && i.FormElementSalesTaxOptions !== null && i.FormElementSalesTaxOptions().length > 0 && (i.ApplySalesTax("yes"), i.ApplyTaxesSelected()),
                  !i.SetPricing() && i.HasConsumerEnteredPrice() && i.ConsumerEnteredPriceChanged(),
                  i.SetPricing() ||
                      i.FormElementAccounts().forEach(function (n) {
                          n.FormAccountId(null);
                      }),
                  i.ValidateFormElementAccounts(),
                  !0
              );
          };
          this.AddDateValueRestrictionChanged = function (n) {
              n ? FormElementDate.AddDateRangeAttribute(i) : FormElementDate.RemoveDateRangeAttributes(i);
          };
          this.SignatureElementValueEntryOptionChanged = function (n) {
              n
                  ? FormElementSignature.SetSignatureAttributeValue(i, FormElementAttributeTypes.ElementValueEntryOption, SignatureTypeEnum.ConsumerEnteredName.toString())
                  : FormElementSignature.SetSignatureAttributeValue(i, FormElementAttributeTypes.ElementValueEntryOption, SignatureTypeEnum.None.toString());
          };
          this.AddConsumerEnteredPriceOption = function () {
              var n = new FormElementOption(i);
              n.ConsumerEnteredPrice(!0);
              i.FormElementOptions.push(n);
          };
          this.RemoveConsumerEnteredPriceOption = function (n) {
              n && i.RemoveOption(n);
          };
          this.ConsumerEnteredPriceChanged = function () {
              if (i.HasConsumerEnteredPrice()) {
                  var n = ko.utils.arrayFilter(i.FormElementOptions(), function (n) {
                      return n.ConsumerEnteredPrice() === !0;
                  });
                  n.forEach(function (n) {
                      i.RemoveOption(n);
                  });
              } else i.AddConsumerEnteredPriceOption(), i.SetPricing() || i.SetPricing(!0);
              return !0;
          };
          this.TrackInventoryChanged = function () {
              return (
                  i.FormElementOptions().forEach(function (n) {
                      n.InventoryOriginalQuantityAvailable = ko.observable(null);
                  }),
                  !0
              );
          };
          this.ApplyTaxesSelected = function () {
              return (
                  i.FormElementSalesTaxOptions !== null &&
                      i.FormElementSalesTaxOptions().length > 0 &&
                      i.FormElementSalesTaxOptions().forEach(function (n) {
                          n.Selected(!0);
                          i.SalesTaxOptionClick(n);
                      }),
                  !0
              );
          };
          this.RemoveTaxesSelected = function () {
              return (
                  i.FormElementSalesTaxes().length > 0 && i.FormElementSalesTaxes.removeAll(),
                  i.FormElementSalesTaxOptions !== null &&
                      i.FormElementSalesTaxOptions().length > 0 &&
                      i.FormElementSalesTaxOptions().forEach(function (n) {
                          n.Selected(!1);
                      }),
                  !0
              );
          };
          this.SalesTaxOptionClick = function (n) {
              var r = n.SalesTaxId,
                  t = ko.utils.arrayFirst(i.FormElementSalesTaxes(), function (n) {
                      return n.SalesTaxId === r;
                  });
              return n.Selected() ? t === null && ((t = new FormElementSalesTax()), (t.FormElementId = i.Id), (t.SalesTaxId = r), i.FormElementSalesTaxes.push(t)) : i.FormElementSalesTaxes.remove(t), !0;
          };
          this.ValidateFormElementAccounts = function () {
              var n = !0;
              i.ElementType() === FormElementTypes.Product &&
                  i.SetPricing() &&
                  i.FormElementAccounts() &&
                  i.FormElementAccounts().length > 1 &&
                  (n =
                      ko.utils.arrayFirst(i.FormElementAccounts(), function (n) {
                          return n.HasAccount();
                      }) !== null);
              i.FormAccountsValid(n);
          };
          this.PostFile = function (n, t) {
              var r = t.currentTarget.files[0],
                  i = new FormData();
              r &&
                  (i.append("file", r),
                  i.append("token", n.Value()),
                  $.ajax({
                      url: "/FormManagement/UpdateImage",
                      type: "POST",
                      data: i,
                      processData: !1,
                      contentType: !1,
                      success: function (t) {
                          t && t.array && t.token ? (n.ImageSource(t.array), n.Value(t.token), n.ValidationErrors("")) : t && t.error && n.ValidationErrors(t.message);
                      },
                  }));
          };
          this.DeletedOptions = n;
          this.DisplayOrder(t);
          this.ElementType.subscribe(this.AttributesAndOptionsSubscription);
          this.AddDateValueRestriction.subscribe(this.AddDateValueRestrictionChanged);
          this.SignatureElementValueEntryOption.subscribe(this.SignatureElementValueEntryOptionChanged);
          this.ShortDescription.subscribe(function (n) {
              n != null && n.length > 0 ? i.ShowShortDescription(!0) : i.ShowShortDescription(!1);
          });
          this.HasConsumerEnteredPrice = ko.computed(function () {
              return (
                  ko.utils.arrayFirst(i.FormElementOptions(), function (n) {
                      return n.ConsumerEnteredPrice() === !0;
                  }) !== null
              );
          });
          this.HasSalesTax = ko.computed(function () {
              return i.FormElementSalesTaxes().length > 0;
          });
          this.DisplaySalesTaxOptions = ko.computed(function () {
              return i.ApplySalesTax() === "yes" && i.FormElementSalesTaxOptions().length > 1;
          });
          this.ApplySalesTax.extend({
              equal: {
                  message: "You must select at least one tax option if Apply Sales Tax is selected",
                  onlyIf: function () {
                      return i.FormElementSalesTaxOptions().length > 0 && !i.HasSalesTax();
                  },
                  params: "no",
              },
          });
          this.FormAccountsValid.extend({ equal: { message: "At least one term must be configured for the product", params: !0 } });
          this.ValidationLabel = ko.computed(function () {
              return i.Text() !== null ? i.Text() : "This field";
          });
          this.CustomerElementType = ko.computed(function () {
              var n = ko.utils.arrayFirst(i.FormElementAttributes(), function (n) {
                  return n.AttributeType() === FormElementAttributeTypes.CustomerElementType;
              });
              return n !== null ? Number(n.Value()) : CustomerElementTypes.None;
          });
          this.IsCustomerDataElement = ko.computed(function () {
              return (
                  ko.utils.arrayFirst(i.FormElementAttributes(), function (n) {
                      return n.AttributeType() === FormElementAttributeTypes.CustomerElementType;
                  }) !== null
              );
          });
          this.IsVisibleInFormBuilder = ko.computed(function () {
              return i.IsCustomerDataElement() ? i.CustomerElementType() == CustomerElementTypes.CustomerLabel : !0;
          });
          this.MinAllowedValueEdit = ko
              .computed({
                  owner: this,
                  read: function () {
                      var n = FormElementDate.GetDateRangeAttributeValue(i, FormElementAttributeTypes.MinAllowedValue);
                      return n !== null ? n : "";
                  },
                  write: function (n) {
                      FormElementDate.SetDateRangeAttributeValue(i, FormElementAttributeTypes.MinAllowedValue, n);
                  },
              })
              .extend({
                  required: {
                      message: "At least one value is required to restrict a date range!",
                      onlyIf: function () {
                          return i.AddDateValueRestriction() && (i.MaxAllowedValueEdit() === null || i.MaxAllowedValueEdit().length === 0);
                      },
                  },
                  date: { message: "Min Date must be a valid date." },
              });
          this.MaxAllowedValueEdit = ko
              .computed({
                  owner: this,
                  read: function () {
                      var n = FormElementDate.GetDateRangeAttributeValue(i, FormElementAttributeTypes.MaxAllowedValue);
                      return n !== null ? n : "";
                  },
                  write: function (n) {
                      FormElementDate.SetDateRangeAttributeValue(i, FormElementAttributeTypes.MaxAllowedValue, n);
                  },
              })
              .extend({ date: { message: "Max Date must be a valid date." } });
          this.NbsTermsHeaderDisplay = ko.computed({
              owner: this,
              read: function () {
                  var n = FormElementSignature.GetSignatureAttributeValue(i, FormElementAttributeTypes.AdditionalText1Header);
                  return n !== null ? n : "";
              },
              write: function (n) {
                  FormElementSignature.SetSignatureAttributeValue(i, FormElementAttributeTypes.AdditionalText1Header, n);
              },
          });
      }
      return n;
  })(),
  FormElementAttribute = (function () {
      function n() {
          var n = this;
          this.Id = 0;
          this.Value = ko.observable("");
          this.AttributeType = ko.observable(FormElementAttributeTypes.ImageToken);
          this.ImageSource = ko.observable(null);
          this.ValidationErrors = ko.observable("");
          this.RemoveImage = function () {
              n.Value("");
          };
          this.HasImage = ko.computed(function () {
              return n.AttributeType() === FormElementAttributeTypes.ImageToken && n.Value().length > 0 ? !0 : !1;
          });
          this.Value.subscribe(function (t) {
              n.AttributeType() === FormElementAttributeTypes.ImageToken &&
                  $.ajax({
                      url: "/FormManagement/GetImageDisplay",
                      type: "POST",
                      data: { token: t },
                      dataType: "json",
                      success: function (t) {
                          t && t.array && t.token && n.ImageSource(t.array);
                      },
                  });
          });
      }
      return n;
  })(),
  ProductDisplayType,
  FormElementAttributeTypes,
  FormElementAttributeTypesFormatTypes,
  CustomerElementTypes,
  FormElementOption,
  FormElementTypes,
  EnterpriseMarketType,
  PrimaryPersonIdCharacterTypes,
  PrimaryPersonIdSpecialFormatTypes;
(function (n) {
  n[(n.Undefined = 0)] = "Undefined";
  n[(n.DropdownList = 1)] = "DropdownList";
  n[(n.RadioButtons = 2)] = "RadioButtons";
  n[(n.CheckboxCollection = 3)] = "CheckboxCollection";
})(ProductDisplayType || (ProductDisplayType = {})),
  (function (n) {
      n[(n.TempItem = 0)] = "TempItem";
      n[(n.FormatType = 1)] = "FormatType";
      n[(n.ImageToken = 2)] = "ImageToken";
      n[(n.ProductDisplayType = 3)] = "ProductDisplayType";
      n[(n.CustomerElementType = 4)] = "CustomerElementType";
      n[(n.PrimaryPersonIdSpecialFormat = 5)] = "PrimaryPersonIdSpecialFormat";
      n[(n.PrimaryPersonIdMinCharacters = 6)] = "PrimaryPersonIdMinCharacters";
      n[(n.PrimaryPersonIdMaxCharacters = 7)] = "PrimaryPersonIdMaxCharacters";
      n[(n.PrimaryPersonIdCharacterType = 8)] = "PrimaryPersonIdCharacterType";
      n[(n.PrimaryPersonIdRegex = 9)] = "PrimaryPersonIdRegex";
      n[(n.PrimaryPersonIdHelpText = 10)] = "PrimaryPersonIdHelpText";
      n[(n.MinAllowedValue = 11)] = "MinAllowedValue";
      n[(n.MaxAllowedValue = 12)] = "MaxAllowedValue";
      n[(n.AdditionalText1 = 13)] = "AdditionalText1";
      n[(n.AdditionalText1Header = 14)] = "AdditionalText1Header";
      n[(n.AdditionalText2 = 15)] = "AdditionalText2";
      n[(n.AdditionalText2Header = 16)] = "AdditionalText2Header";
      n[(n.ElementValueEntryOption = 17)] = "ElementValueEntryOption";
  })(FormElementAttributeTypes || (FormElementAttributeTypes = {})),
  (function (n) {
      n[(n.None = 0)] = "None";
      n[(n.PlainText = 1)] = "PlainText";
      n[(n.Email = 2)] = "Email";
      n[(n.Number = 3)] = "Number";
      n[(n.Phone = 4)] = "Phone";
  })(FormElementAttributeTypesFormatTypes || (FormElementAttributeTypesFormatTypes = {})),
  (function (n) {
      n[(n.None = 0)] = "None";
      n[(n.CustomerLabel = 1)] = "CustomerLabel";
      n[(n.CustomerFirstName = 2)] = "CustomerFirstName";
      n[(n.CustomerLastName = 3)] = "CustomerLastName";
      n[(n.CustomerEmailAddress = 4)] = "CustomerEmailAddress";
      n[(n.CustomerAddress1 = 5)] = "CustomerAddress1";
      n[(n.CustomerAddress2 = 6)] = "CustomerAddress2";
      n[(n.CustomerCity = 7)] = "CustomerCity";
      n[(n.CustomerStateProvince = 8)] = "CustomerStateProvince";
      n[(n.CustomerPostalCode = 9)] = "CustomerPostalCode";
      n[(n.CustomerCountry = 10)] = "CustomerCountry";
      n[(n.DaytimePhone = 11)] = "DaytimePhone";
      n[(n.EveningPhone = 12)] = "EveningPhone";
      n[(n.MobilePhone = 13)] = "MobilePhone";
      n[(n.PrimaryPersonId = 14)] = "PrimaryPersonId";
      n[(n.ConfirmPrimaryPersonId = 15)] = "ConfirmPrimaryPersonId";
  })(CustomerElementTypes || (CustomerElementTypes = {}));
(FormElementOption = (function () {
  function n(n) {
      var t = this;
      this.Id = 0;
      this.Name = ko.observable();
      this.Price = ko.observable(0);
      this.Deleted = ko.observable(!1);
      this.AllowQuantityPurchase = ko.observable(!1);
      this.ConsumerEnteredPrice = ko.observable(!1);
      this.MaxPrice = ko.observable(null);
      this.MinPrice = ko.observable(null);
      this.InventoryTransactionTotal = ko.observable(0);
      this.InventoryOriginalQuantityAvailable = ko.observable(null).extend({
          min: {
              params: this.InventoryTransactionTotal,
              message: "New available quantity must be greater than or equal to {0}.",
              onlyIf: function () {
                  return n.TrackInventory();
              },
          },
      });
      this.Name.extend({
          required: {
              message: "Option Name is required",
              onlyIf: function () {
                  return !t.Deleted();
              },
          },
      });
      this.Price.extend({
          min: {
              params: 0,
              message: "Price cannot be negative",
              onlyIf: function () {
                  return t.Price() !== null && !t.Deleted();
              },
          },
      });
      this.MinPrice.extend({
          min: {
              params: 0,
              message: "Min. Price cannot be negative",
              onlyIf: function () {
                  return t.ConsumerEnteredPrice() && !t.Deleted();
              },
          },
      });
      this.MaxPrice.extend({
          min: {
              params: 0.01,
              message: "Max. Price must be greater than 0.00",
              onlyIf: function () {
                  return t.ConsumerEnteredPrice() && !t.Deleted();
              },
          },
          required: {
              message: "Max. Price must be greater than 0.00",
              onlyIf: function () {
                  return t.ConsumerEnteredPrice() && !t.Deleted();
              },
          },
      });
      this.PriceEdit = ko.pureComputed({
          owner: this,
          read: function () {
              return t.Price() != null ? t.Price().toFixed(2) : "0.00";
          },
          write: function (n) {
              var i = parseFloat(n);
              isNaN(i) ? t.Price(0) : t.Price(i);
          },
      });
      this.MinPriceEdit = ko.pureComputed({
          owner: this,
          read: function () {
              return t.MinPrice() !== null ? t.MinPrice().toFixed(2) : "0.00";
          },
          write: function (n) {
              var i = parseFloat(n);
              isNaN(i) ? t.MinPrice(0) : t.MinPrice(i);
          },
      });
      this.MaxPriceEdit = ko.pureComputed({
          owner: this,
          read: function () {
              return t.MaxPrice() !== null ? t.MaxPrice().toFixed(2) : "0.00";
          },
          write: function (n) {
              var i = parseFloat(n);
              isNaN(i) ? t.MaxPrice(0) : t.MaxPrice(i);
          },
      });
  }
  return n;
})()),
  (function (n) {
      n[(n.Undefined = 0)] = "Undefined";
      n[(n.SingleLineText = 1)] = "SingleLineText";
      n[(n.MultiLineText = 2)] = "MultiLineText";
      n[(n.Checkboxes = 3)] = "Checkboxes";
      n[(n.DropdownList = 4)] = "DropdownList";
      n[(n.RadioButtons = 5)] = "RadioButtons";
      n[(n.Image = 6)] = "Image";
      n[(n.Heading = 7)] = "Heading";
      n[(n.Paragraph = 8)] = "Paragraph";
      n[(n.Product = 9)] = "Product";
      n[(n.CustomerData = 10)] = "CustomerData";
      n[(n.Date = 11)] = "Date";
      n[(n.Signature = 12)] = "Signature";
  })(FormElementTypes || (FormElementTypes = {}));
var __extends =
      (this && this.__extends) ||
      (function () {
          var n = function (t, i) {
              return (
                  (n =
                      Object.setPrototypeOf ||
                      ({ __proto__: [] } instanceof Array &&
                          function (n, t) {
                              n.__proto__ = t;
                          }) ||
                      function (n, t) {
                          for (var i in t) Object.prototype.hasOwnProperty.call(t, i) && (n[i] = t[i]);
                      }),
                  n(t, i)
              );
          };
          return function (t, i) {
              function r() {
                  this.constructor = t;
              }
              n(t, i);
              t.prototype = i === null ? Object.create(i) : ((r.prototype = i.prototype), new r());
          };
      })(),
  FormHeading = (function (n) {
      function t(t, i) {
          var r = n.call(this, t, i) || this;
          return (r.ElementType = ko.observable(FormElementTypes.Heading)), r;
      }
      return __extends(t, n), t;
  })(FormElement),
  __extends =
      (this && this.__extends) ||
      (function () {
          var n = function (t, i) {
              return (
                  (n =
                      Object.setPrototypeOf ||
                      ({ __proto__: [] } instanceof Array &&
                          function (n, t) {
                              n.__proto__ = t;
                          }) ||
                      function (n, t) {
                          for (var i in t) Object.prototype.hasOwnProperty.call(t, i) && (n[i] = t[i]);
                      }),
                  n(t, i)
              );
          };
          return function (t, i) {
              function r() {
                  this.constructor = t;
              }
              n(t, i);
              t.prototype = i === null ? Object.create(i) : ((r.prototype = i.prototype), new r());
          };
      })(),
  FormImage = (function (n) {
      function t(t, i) {
          var r = n.call(this, t, i) || this,
              u;
          return (r.ElementType = ko.observable(FormElementTypes.Image)), (u = new FormElementAttribute()), u.AttributeType(FormElementAttributeTypes.ImageToken), r.FormElementAttributes.push(u), r;
      }
      return __extends(t, n), t;
  })(FormElement),
  __extends =
      (this && this.__extends) ||
      (function () {
          var n = function (t, i) {
              return (
                  (n =
                      Object.setPrototypeOf ||
                      ({ __proto__: [] } instanceof Array &&
                          function (n, t) {
                              n.__proto__ = t;
                          }) ||
                      function (n, t) {
                          for (var i in t) Object.prototype.hasOwnProperty.call(t, i) && (n[i] = t[i]);
                      }),
                  n(t, i)
              );
          };
          return function (t, i) {
              function r() {
                  this.constructor = t;
              }
              n(t, i);
              t.prototype = i === null ? Object.create(i) : ((r.prototype = i.prototype), new r());
          };
      })(),
  FormParagraph = (function (n) {
      function t(t, i) {
          var r = n.call(this, t, i) || this;
          return (r.ElementType = ko.observable(FormElementTypes.Paragraph)), r;
      }
      return __extends(t, n), t;
  })(FormElement),
  __extends =
      (this && this.__extends) ||
      (function () {
          var n = function (t, i) {
              return (
                  (n =
                      Object.setPrototypeOf ||
                      ({ __proto__: [] } instanceof Array &&
                          function (n, t) {
                              n.__proto__ = t;
                          }) ||
                      function (n, t) {
                          for (var i in t) Object.prototype.hasOwnProperty.call(t, i) && (n[i] = t[i]);
                      }),
                  n(t, i)
              );
          };
          return function (t, i) {
              function r() {
                  this.constructor = t;
              }
              n(t, i);
              t.prototype = i === null ? Object.create(i) : ((r.prototype = i.prototype), new r());
          };
      })(),
  FormProduct = (function (n) {
      function t(t, i, r) {
          var u = n.call(this, t, i) || this,
              f;
          return (
              (u.ElementType = ko.observable(FormElementTypes.Product)), (u.FormTerms = r), (f = new FormElementAttribute()), f.AttributeType(FormElementAttributeTypes.ProductDisplayType), f.Value("1"), u.FormElementAttributes.push(f), u
          );
      }
      return __extends(t, n), t;
  })(FormElement),
  __extends =
      (this && this.__extends) ||
      (function () {
          var n = function (t, i) {
              return (
                  (n =
                      Object.setPrototypeOf ||
                      ({ __proto__: [] } instanceof Array &&
                          function (n, t) {
                              n.__proto__ = t;
                          }) ||
                      function (n, t) {
                          for (var i in t) Object.prototype.hasOwnProperty.call(t, i) && (n[i] = t[i]);
                      }),
                  n(t, i)
              );
          };
          return function (t, i) {
              function r() {
                  this.constructor = t;
              }
              n(t, i);
              t.prototype = i === null ? Object.create(i) : ((r.prototype = i.prototype), new r());
          };
      })(),
  FormElementCustomerData = (function (n) {
      function t(t, i) {
          var r = n.call(this, t, i) || this;
          return (r.ElementType = ko.observable(FormElementTypes.CustomerData)), r;
      }
      return (
          __extends(t, n),
          (t.AddCustomerLabelField = function (n, i, r, u) {
              var f = t.CreateCustomerElement(CustomerElementTypes.CustomerLabel, r, u);
              return i !== undefined && i.length > 0 && f.Text(i), n.push(f), f;
          }),
          (t.AddCustomerNameFields = function (n, i, r) {
              n.push(t.CreateCustomerElement(CustomerElementTypes.CustomerFirstName, i, r));
              n.push(t.CreateCustomerElement(CustomerElementTypes.CustomerLastName, i, r));
          }),
          (t.AddCustomerAddressFields = function (n, i, r) {
              n.push(t.CreateCustomerElement(CustomerElementTypes.CustomerCountry, i, r));
              n.push(t.CreateCustomerElement(CustomerElementTypes.CustomerAddress1, i, r));
              n.push(t.CreateCustomerElement(CustomerElementTypes.CustomerAddress2, i, r));
              n.push(t.CreateCustomerElement(CustomerElementTypes.CustomerCity, i, r));
              n.push(t.CreateCustomerElement(CustomerElementTypes.CustomerStateProvince, i, r));
              n.push(t.CreateCustomerElement(CustomerElementTypes.CustomerPostalCode, i, r));
          }),
          (t.AddCustomerField = function (n, i, r, u) {
              i.push(t.CreateCustomerElement(n, r, u));
          }),
          (t.AddPrimaryPersonIdField = function (n, i, r) {
              var f = t.CreateCustomerElement(CustomerElementTypes.PrimaryPersonId, i, r),
                  u;
              n.push(f);
              u = new FormElementAttribute();
              u.AttributeType(FormElementAttributeTypes.PrimaryPersonIdSpecialFormat);
              u.Value("0");
              f.FormElementAttributes.push(u);
          }),
          (t.AddPrimaryPersonCharacterLimitAttributes = function (n) {
              if (n !== undefined) {
                  var t = new FormElementAttribute();
                  t.AttributeType(FormElementAttributeTypes.PrimaryPersonIdMinCharacters);
                  n.FormElementAttributes.push(t);
                  t = new FormElementAttribute();
                  t.AttributeType(FormElementAttributeTypes.PrimaryPersonIdMaxCharacters);
                  n.FormElementAttributes.push(t);
                  t = new FormElementAttribute();
                  t.AttributeType(FormElementAttributeTypes.PrimaryPersonIdCharacterType);
                  n.FormElementAttributes.push(t);
              }
          }),
          (t.AddPrimaryPersonDefinedFormatAttributes = function (n) {
              if (n !== undefined) {
                  var t = new FormElementAttribute();
                  t.AttributeType(FormElementAttributeTypes.PrimaryPersonIdRegex);
                  n.FormElementAttributes.push(t);
                  t = new FormElementAttribute();
                  t.AttributeType(FormElementAttributeTypes.PrimaryPersonIdHelpText);
                  n.FormElementAttributes.push(t);
              }
          }),
          (t.RemovePrimaryPersonIdAttributes = function (n) {
              if (n !== undefined) {
                  var i = t.GetPrimaryPersonIdAttribute(n, FormElementAttributeTypes.PrimaryPersonIdSpecialFormat);
                  i !== null && n.FormElementAttributes.remove(i);
                  t.RemovePrimaryPersonSpecialFormatAttributes(n);
              }
          }),
          (t.RemovePrimaryPersonSpecialFormatAttributes = function (n) {
              if (n !== undefined) {
                  var i = t.GetPrimaryPersonIdAttribute(n, FormElementAttributeTypes.PrimaryPersonIdMinCharacters);
                  i !== null && n.FormElementAttributes.remove(i);
                  i = t.GetPrimaryPersonIdAttribute(n, FormElementAttributeTypes.PrimaryPersonIdMaxCharacters);
                  i !== null && n.FormElementAttributes.remove(i);
                  i = t.GetPrimaryPersonIdAttribute(n, FormElementAttributeTypes.PrimaryPersonIdCharacterType);
                  i !== null && n.FormElementAttributes.remove(i);
                  i = t.GetPrimaryPersonIdAttribute(n, FormElementAttributeTypes.PrimaryPersonIdRegex);
                  i !== null && n.FormElementAttributes.remove(i);
                  i = t.GetPrimaryPersonIdAttribute(n, FormElementAttributeTypes.PrimaryPersonIdHelpText);
                  i !== null && n.FormElementAttributes.remove(i);
              }
          }),
          (t.GetPrimaryPersonIdAttribute = function (n, t) {
              return n !== null
                  ? ko.utils.arrayFirst(n.FormElementAttributes(), function (n) {
                        return n.AttributeType() === t;
                    })
                  : null;
          }),
          (t.GetPrimaryPersonIdAttributeValue = function (n, i) {
              var r = t.GetPrimaryPersonIdAttribute(n, i);
              return r !== null ? r.Value() : "";
          }),
          (t.SetPrimaryPersonIdAttributeValue = function (n, i, r) {
              var u = t.GetPrimaryPersonIdAttribute(n, i);
              u !== null && u.Value(r);
          }),
          (t.CreateCustomerElement = function (n, i, r) {
              var u = new t(i, r),
                  f = new FormElementAttribute(),
                  e = !0;
              f.AttributeType(FormElementAttributeTypes.CustomerElementType);
              f.Value(n.toString());
              u.FormElementAttributes.push(f);
              switch (n) {
                  case CustomerElementTypes.CustomerLabel:
                      u.Text("Customer");
                      e = !1;
                      break;
                  case CustomerElementTypes.CustomerAddress1:
                      u.Text("Street Address 1");
                      break;
                  case CustomerElementTypes.CustomerAddress2:
                      u.Text("Street Address 2");
                      e = !1;
                      break;
                  case CustomerElementTypes.CustomerFirstName:
                      u.Text("First Name");
                      break;
                  case CustomerElementTypes.CustomerLastName:
                      u.Text("Last Name");
                      break;
                  case CustomerElementTypes.CustomerCity:
                      u.Text("City");
                      break;
                  case CustomerElementTypes.CustomerStateProvince:
                      u.Text("State");
                      break;
                  case CustomerElementTypes.CustomerCountry:
                      u.Text("Country");
                      break;
                  case CustomerElementTypes.CustomerPostalCode:
                      u.Text("Postal Code");
                      break;
                  case CustomerElementTypes.CustomerEmailAddress:
                      u.Text("Email Address");
                      break;
                  case CustomerElementTypes.DaytimePhone:
                      u.Text("Office Phone");
                      break;
                  case CustomerElementTypes.EveningPhone:
                      u.Text("Home Phone");
                      break;
                  case CustomerElementTypes.MobilePhone:
                      u.Text("Mobile Phone");
                      break;
                  case CustomerElementTypes.PrimaryPersonId:
                      u.Text("ID");
              }
              return u.Required(e), u;
          }),
          t
      );
  })(FormElement),
  __extends =
      (this && this.__extends) ||
      (function () {
          var n = function (t, i) {
              return (
                  (n =
                      Object.setPrototypeOf ||
                      ({ __proto__: [] } instanceof Array &&
                          function (n, t) {
                              n.__proto__ = t;
                          }) ||
                      function (n, t) {
                          for (var i in t) Object.prototype.hasOwnProperty.call(t, i) && (n[i] = t[i]);
                      }),
                  n(t, i)
              );
          };
          return function (t, i) {
              function r() {
                  this.constructor = t;
              }
              n(t, i);
              t.prototype = i === null ? Object.create(i) : ((r.prototype = i.prototype), new r());
          };
      })(),
  FormElementDate = (function (n) {
      function t() {
          return (n !== null && n.apply(this, arguments)) || this;
      }
      return (
          __extends(t, n),
          (t.AddDateRangeAttribute = function (n) {
              if (n !== undefined && n !== null)
                  if (n.FormElementAttributes().length === 0) t.AddMinAttribute(n), t.AddMaxAttribute(n);
                  else {
                      var i = t.GetDateRangeAttribute(n, FormElementAttributeTypes.MinAllowedValue);
                      i === null ? t.AddMinAttribute(n) : t.AddMaxAttribute(n);
                  }
          }),
          (t.AddMinAttribute = function (n) {
              var t = new FormElementAttribute();
              t.AttributeType(FormElementAttributeTypes.MinAllowedValue);
              n.FormElementAttributes.push(t);
          }),
          (t.AddMaxAttribute = function (n) {
              var t = new FormElementAttribute();
              t.AttributeType(FormElementAttributeTypes.MaxAllowedValue);
              n.FormElementAttributes.push(t);
          }),
          (t.GetDateRangeAttribute = function (n, t) {
              return n !== null
                  ? ko.utils.arrayFirst(n.FormElementAttributes(), function (n) {
                        return n.AttributeType() === t;
                    })
                  : null;
          }),
          (t.GetDateRangeAttributeValue = function (n, i) {
              var r = t.GetDateRangeAttribute(n, i);
              return r !== null ? r.Value() : "";
          }),
          (t.SetDateRangeAttributeValue = function (n, i, r) {
              var u = t.GetDateRangeAttribute(n, i);
              u !== null && u.Value(r);
          }),
          (t.RemoveDateRangeAttributes = function (n) {
              var i, r;
              n !== undefined &&
                  ((i = t.GetDateRangeAttribute(n, FormElementAttributeTypes.MinAllowedValue)),
                  i !== null && n.FormElementAttributes.remove(i),
                  (r = t.GetDateRangeAttribute(n, FormElementAttributeTypes.MaxAllowedValue)),
                  r !== null && n.FormElementAttributes.remove(r));
          }),
          t
      );
  })(FormElement),
  __extends =
      (this && this.__extends) ||
      (function () {
          var n = function (t, i) {
              return (
                  (n =
                      Object.setPrototypeOf ||
                      ({ __proto__: [] } instanceof Array &&
                          function (n, t) {
                              n.__proto__ = t;
                          }) ||
                      function (n, t) {
                          for (var i in t) Object.prototype.hasOwnProperty.call(t, i) && (n[i] = t[i]);
                      }),
                  n(t, i)
              );
          };
          return function (t, i) {
              function r() {
                  this.constructor = t;
              }
              n(t, i);
              t.prototype = i === null ? Object.create(i) : ((r.prototype = i.prototype), new r());
          };
      })(),
  FormElementSignature = (function (n) {
      function t(i, r, u) {
          var f = n.call(this, r, u) || this,
              e,
              o;
          return (
              (f.ElementType = ko.observable(FormElementTypes.Signature)),
              f.Required(!0),
              (f.Text = ko.observable("Electronic Signature")),
              (e = "Nelnet Terms and Conditions"),
              (o = i + " Terms and Conditions"),
              t.AddSignatureAttribute(f, FormElementAttributeTypes.AdditionalText1Header, e),
              t.AddSignatureAttribute(f, FormElementAttributeTypes.AdditionalText2Header, o),
              t.AddSignatureAttribute(f, FormElementAttributeTypes.AdditionalText2, ""),
              t.AddSignatureAttribute(f, FormElementAttributeTypes.ElementValueEntryOption, SignatureTypeEnum.None.toString()),
              f
          );
      }
      return (
          __extends(t, n),
          (t.AddSignatureAttribute = function (n, t, i) {
              var r = new FormElementAttribute();
              r.AttributeType(t);
              i !== null && r.Value(i);
              n.FormElementAttributes.push(r);
          }),
          (t.RemoveSignatureAttribute = function (n, i) {
              if (n !== undefined) {
                  var r = t.GetSignatureAttribute(n, i);
                  r !== null && n.FormElementAttributes.remove(r);
              }
          }),
          (t.RemoveAllSignatureAttributes = function (n) {
              n !== undefined &&
                  n.FormElementAttributes().forEach(function (i) {
                      t.RemoveSignatureAttribute(n, i.AttributeType());
                  });
          }),
          (t.SetSignatureAttributeValue = function (n, i, r) {
              var u = t.GetSignatureAttribute(n, i);
              u !== null && u.Value(r);
          }),
          (t.GetSignatureAttributeValue = function (n, i) {
              var r = t.GetSignatureAttribute(n, i);
              return r !== null ? r.Value() : "";
          }),
          (t.GetSignatureAttribute = function (n, t) {
              return n !== null
                  ? ko.utils.arrayFirst(n.FormElementAttributes(), function (n) {
                        return n.AttributeType() === t;
                    })
                  : null;
          }),
          t
      );
  })(FormElement),
  SignatureTypeEnum;
(function (n) {
  n[(n.None = 0)] = "None";
  n[(n.ConsumerEnteredName = 1)] = "ConsumerEnteredName";
})(SignatureTypeEnum || (SignatureTypeEnum = {})),
  (function (n) {
      n[(n.None = 0)] = "None";
      n[(n.K12 = 1)] = "K12";
      n[(n.HigherEd = 2)] = "HigherEd";
      n[(n.Synagogue = 3)] = "Synagogue";
  })(EnterpriseMarketType || (EnterpriseMarketType = {}));
var FormAccount = (function () {
      function n() {
          var n = this;
          this.Id = 0;
          this.AccountCode = ko.observable("");
          this.AdjustmentCode = ko.observable("");
          this.Deleted = ko.observable(!1);
          this.AssignedToProduct = ko.observable(!1);
          this.Suppressed = ko.observable(!1);
          this.AccountCode.extend({
              required: {
                  message: "Institution Account is required",
                  onlyIf: function () {
                      return !n.Deleted();
                  },
              },
          });
          this.AdjustmentCode.extend({
              required: {
                  message: "Adjustment Reason is required",
                  onlyIf: function () {
                      return !n.Deleted();
                  },
              },
          });
      }
      return n;
  })(),
  FormTerm = (function () {
      function n(n) {
          var t = this;
          this.Id = 0;
          this.TermCode = ko.observable("");
          this.TermKey = ko.observable("");
          this.TermName = "";
          this.Deleted = ko.observable(!1);
          this.HideTerm = ko.observable(!1);
          this.FormAccounts = ko.observableArray([]);
          this.OriginalTermCode = "";
          this.AssignedToProduct = ko.observable(!1);
          this.AccountList = ko.observableArray([]);
          this.AdjustmentCodeList = ko.observableArray([]);
          this.AvailableTerms = Array();
          this.TermCodeUnique = function () {
              var n = !0;
              return (
                  t.ParentFormProperties &&
                      t.ParentFormProperties.FormTerms() &&
                      (n =
                          ko.utils.arrayFilter(t.ParentFormProperties.FormTerms(), function (n) {
                              return n.TermCode() == t.TermCode();
                          }).length < 2),
                  n
              );
          };
          this.IsNew = function () {
              return t.Id == 0;
          };
          this.AddFormAccount = function () {
              t.FormAccounts.push(new FormAccount());
          };
          this.RemoveFormAccount = function (n) {
              n.Deleted(!0);
              t.FormAccounts.remove(n);
          };
          this.ClearFormAccounts = function () {
              while (t.FormAccounts().length > 0) t.RemoveFormAccount(t.FormAccounts()[0]);
          };
          this.GetEpayProfileId = function (n) {
              var i = ko.utils.arrayFirst(t.AccountList(), function (t) {
                  return t.Code === n;
              });
              return i !== null ? i.EPayProfileId : 0;
          };
          this.TermSelected = function (n) {
              var r = t,
                  i;
              t.AccountList([]);
              t.AdjustmentCodeList([]);
              n &&
                  ((i = ko.utils.arrayFirst(t.AvailableTerms, function (n) {
                      return n.Code === t.TermCode();
                  })),
                  i.Accounts.forEach(function (n) {
                      t.AccountList.push(n);
                  }),
                  i.AdjustmentReasons.forEach(function (n) {
                      t.AdjustmentCodeList.push(n);
                  }));
              n != t.OriginalTermCode &&
                  t.FormAccounts() &&
                  t.FormAccounts().forEach(function (n) {
                      n.AssignedToProduct(!1);
                  });
              t.ParentFormProperties && t.ParentFormProperties.TermSelected();
          };
          this.AvailableTerms = n;
          this.TermSelected(this.TermCode());
          this.AccountListNonSuppressedOnly = ko.computed(function () {
              return ko.utils.arrayFilter(t.AccountList(), function (n) {
                  return !n.Suppressed || n.AvailableForInst;
              });
          });
          this.TermCode.subscribe(this.TermSelected);
          this.TermCode.extend({
              required: {
                  message: "Term is required",
                  onlyIf: function () {
                      return !t.Deleted();
                  },
              },
              validation: {
                  validator: this.TermCodeUnique,
                  message: "Each term can only be added to the form once",
                  onlyIf: function () {
                      return t.ParentFormProperties;
                  },
              },
          });
          this.AccountsValid = ko.computed(function () {
              var n = !0,
                  i;
              return (
                  t.FormAccounts() &&
                      t.FormAccounts().length > 0 &&
                      ((i = t.GetEpayProfileId(t.FormAccounts()[0].AccountCode())),
                      t.FormAccounts().forEach(function (r) {
                          var u = r.Deleted() ? 0 : t.GetEpayProfileId(r.AccountCode());
                          n && u > 0 && u !== i && (n = !1);
                      })),
                  n
              );
          });
          this.AccountsValid.extend({ equal: { message: "All Accounts must be associated with the same EPay Profile", params: !0 } });
      }
      return n;
  })(),
  Money = (function () {
      function n() {
          var t = this;
          this.Amount = ko.observable(0);
          this.FormattedValue = ko.computed(function () {
              var i = n.RoundToEven(t.Amount(), 2).toFixed(2).replace("-", "").split("."),
                  r =
                      "$" +
                      $.map(i[0].split("").reverse(), function (n, t) {
                          return [t % 3 == 0 && t > 0 ? "," : "", n];
                      })
                          .reverse()
                          .join("") +
                      "." +
                      i[1];
              return t.Amount() < 0 ? "-" + r : r;
          });
      }
      return (
          (n.RoundToEven = function (n, t) {
              t === void 0 && (t = 2);
              var r = t || 0,
                  f = Math.pow(10, r),
                  u = +(r ? n * f : n).toFixed(8),
                  i = Math.floor(u),
                  e = u - i,
                  o = 1e-8,
                  s = e > 0.5 - o && e < 0.5 + o ? (i % 2 == 0 ? i : i + 1) : Math.round(u);
              return r ? s / f : s;
          }),
          (n.ToCurrency = function (t) {
              return n.RoundToEven(t, 2);
          }),
          (n.ToFormattedCurrency = function (t) {
              var i = n.ToCurrency(t).toFixed(2).replace("-", "").split("."),
                  r =
                      "$" +
                      $.map(i[0].split("").reverse(), function (n, t) {
                          return [t % 3 == 0 && t > 0 ? "," : "", n];
                      })
                          .reverse()
                          .join("") +
                      "." +
                      i[1];
              return t < 0 ? "-" + r : r;
          }),
          n
      );
  })(),
  MessageRecipient = (function () {
      function n() {
          this.Id = 0;
          this.Address = ko.observable("");
          this.Address.extend({ email: { message: "Email address is invalid" }, maxLength: { params: 256, message: "Email address must be less than {0} characters" }, required: { message: "Email address is required" } });
      }
      return n;
  })(),
  SalesTax = (function () {
      function n() {
          var n = this;
          this.Id = 0;
          this.Name = ko.observable("");
          this.AccountCode = ko.observable("");
          this.AdjustmentCode = ko.observable("");
          this.Percentage = ko.observable(0);
          this.Deleted = ko.observable(!1);
          this.Name.extend({
              required: {
                  message: "Tax Name/Description is required",
                  onlyIf: function () {
                      return !n.Deleted();
                  },
              },
          });
          this.AccountCode.extend({
              required: {
                  message: "Institution Account is required",
                  onlyIf: function () {
                      return !n.Deleted();
                  },
              },
          });
          this.AdjustmentCode.extend({
              required: {
                  message: "Adjustment Reason is required",
                  onlyIf: function () {
                      return !n.Deleted();
                  },
              },
          });
          this.Percentage.extend({
              min: {
                  params: 0.0001,
                  message: "Percentage must be greater than 0.00",
                  onlyIf: function () {
                      return !n.Deleted();
                  },
              },
              max: {
                  params: 99.9999,
                  message: "Percentage must be less than 100",
                  onlyIf: function () {
                      return !n.Deleted();
                  },
              },
          });
      }
      return n;
  })(),
  CustomerSalesTax = (function () {
      function n(n) {
          var t = this;
          this.Id = 0;
          this.Name = ko.observable("");
          this.Percentage = ko.observable(0);
          this.TotalTax = ko.observable(new Money());
          this.Id = n.Id;
          this.Name(n.Name());
          this.Percentage(n.Percentage());
          this.TaxAccumulator = 0;
          this.Rate = ko.computed(function () {
              return t.Percentage() / 100;
          });
      }
      return n;
  })(),
  FormElementSalesTax = (function () {
      function n() {
          this.Id = 0;
          this.FormElementId = 0;
          this.SalesTaxId = 0;
      }
      return n;
  })(),
  __extends =
      (this && this.__extends) ||
      (function () {
          var n = function (t, i) {
              return (
                  (n =
                      Object.setPrototypeOf ||
                      ({ __proto__: [] } instanceof Array &&
                          function (n, t) {
                              n.__proto__ = t;
                          }) ||
                      function (n, t) {
                          for (var i in t) Object.prototype.hasOwnProperty.call(t, i) && (n[i] = t[i]);
                      }),
                  n(t, i)
              );
          };
          return function (t, i) {
              function r() {
                  this.constructor = t;
              }
              n(t, i);
              t.prototype = i === null ? Object.create(i) : ((r.prototype = i.prototype), new r());
          };
      })(),
  FormElementSalesTaxOption = (function (n) {
      function t() {
          var t = (n !== null && n.apply(this, arguments)) || this;
          return (t.Name = ""), (t.Selected = ko.observable(!1)), t;
      }
      return __extends(t, n), t;
  })(FormElementSalesTax),
  FormElementAccount = (function () {
      function n(n, t, i) {
          var r = this;
          i === void 0 && (i = 0);
          this.Id = 0;
          this.FormElementId = 0;
          this.FormTermId = 0;
          this.FormAccountId = ko.observable();
          this.Deleted = ko.observable(!1);
          this.FormTerms = Array();
          this.AssignedToProduct = ko.observable(!1);
          this.AvailableFormAccounts = function () {
              var n = ko.utils.arrayFirst(r.FormTerms, function (n) {
                  return n.Id === r.FormTermId;
              });
              return n.FormAccounts();
          };
          this.TermDisplay = function () {
              var n = ko.utils.arrayFirst(r.FormTerms, function (n) {
                  return n.Id === r.FormTermId;
              });
              return n.TermName;
          };
          this.FormTerms = n;
          i > 0 && this.FormAccountId(i);
          this.HasAccount = ko.computed(function () {
              return r.FormAccountId() && r.FormAccountId() > 0;
          });
          this.FormAccountId.subscribe(function () {
              t.ValidateFormElementAccounts();
          });
      }
      return n;
  })(),
  CountryCode;
(function (n) {
  n[(n.None = 0)] = "None";
  n[(n.USA = 1)] = "USA";
  n[(n.AUS = 2)] = "AUS";
  n[(n.NZL = 3)] = "NZL";
})(CountryCode || (CountryCode = {})),
  (function (n) {
      n[(n.None = 0)] = "None";
      n[(n.Alpha = 1)] = "Alpha";
      n[(n.Combination = 2)] = "Combination";
      n[(n.Numeric = 3)] = "Numeric";
  })(PrimaryPersonIdCharacterTypes || (PrimaryPersonIdCharacterTypes = {})),
  (function (n) {
      n[(n.None = 0)] = "None";
      n[(n.CharacterLimit = 1)] = "CharacterLimit";
      n[(n.DefinedFormat = 2)] = "DefinedFormat";
  })(PrimaryPersonIdSpecialFormatTypes || (PrimaryPersonIdSpecialFormatTypes = {}));
var Term = (function () {
      function n() {}
      return n;
  })(),
  InstAccount = (function () {
      function n() {}
      return n;
  })(),
  AdjustmentReason = (function () {
      function n() {}
      return n;
  })(),
  ElementMapperEngine = (function () {
      function n() {
          var n = this;
          this.ConvertElementToCustomerElement = function (n, t, i) {
              var r = new CustomerFormElement(),
                  y,
                  f,
                  p,
                  u,
                  w,
                  b,
                  h,
                  c,
                  s,
                  g;
              for (
                  r.SectionName = n.Text(),
                      r.ElementId = n.Id,
                      r.ElementType = n.ElementType(),
                      r.Options = [],
                      r.Attributes = [],
                      r.AllowQuantityPurchase = n.AllowQuantityPurchase(),
                      r.SetPricing = n.SetPricing(),
                      r.Required = n.Required(),
                      r.TrackInventory = n.TrackInventory(),
                      r.SalesTaxIds = [],
                      r.FormElementAccounts = [],
                      n.FormElementAccounts !== null &&
                          n.FormElementAccounts().forEach(function (n) {
                              var t = new CustomerFormElementAccount();
                              t.Id = n.Id;
                              t.FormElementId = n.FormElementId;
                              t.FormTermId = n.FormTermId;
                              t.FormAccountId = n.FormAccountId();
                              t.HasAccount = n.HasAccount();
                              r.FormElementAccounts.push(t);
                          }),
                      u = 0;
                  u < n.FormElementAttributes().length;
                  u++
              )
                  (y = new CustomerFormElementAttribute(n.FormElementAttributes()[u])), r.Attributes.push(y);
              for (
                  (r.ElementType === FormElementTypes.RadioButtons || (r.ElementType === FormElementTypes.Product && +r.Attributes.length > 0 && +r.Attributes[0].Value === ProductDisplayType.RadioButtons)) &&
                      !n.Required &&
                      ((f = new FormElementOption(n)), (f.Id = 0), f.Price(0), f.Name("None"), (f.InventoryCurrentQuantityAvailable = null), (p = new CustomerFormElementOption(f, n)), r.Options.push(p)),
                      n.HasSalesTax() &&
                          n.FormElementSalesTaxes().forEach(function (n) {
                              var t = n.SalesTaxId;
                              r.SalesTaxIds.push(t);
                          }),
                      u = 0;
                  u < n.FormElementOptions().length;
                  u++
              )
                  (w = new CustomerFormElementOption(n.FormElementOptions()[u], n)), r.Options.push(w);
              if (
                  (r.ElementType === FormElementTypes.Product && +r.Attributes[0].Value === ProductDisplayType.CheckboxCollection
                      ? (r.Value = ko.observableArray(null).extend({
                            required: {
                                params: n.ValidationLabel,
                                message: "{0} is a required field.",
                                onlyIf: function () {
                                    return n.Required() && !r.HiddenForTerm();
                                },
                            },
                        }))
                      : ((r.Value = ko.observable(null).extend({
                            required: {
                                params: n.ValidationLabel,
                                message: "{0} is a required field.",
                                onlyIf: function () {
                                    return n.Required() && !r.HiddenForTerm();
                                },
                            },
                        })),
                        r.ElementType === FormElementTypes.Product &&
                            (+r.Attributes[0].Value === ProductDisplayType.RadioButtons || +r.Attributes[0].Value === ProductDisplayType.DropdownList) &&
                            r.Value.subscribe(function (n) {
                                r.Options.forEach(function (n) {
                                    n.Selected(!1);
                                    n.Quantity(1);
                                });
                                n != null && n.Selected(!0);
                            })),
                  r.ElementType === FormElementTypes.Checkboxes)
              )
                  r.Value = ko.observableArray().extend({
                      required: {
                          params: n.ValidationLabel,
                          message: "{0} is a required field.",
                          onlyIf: function () {
                              return n.Required();
                          },
                      },
                  });
              else if (r.ElementType === FormElementTypes.SingleLineText) {
                  b = +n.FormElementAttributes()[0].Value();
                  switch (b) {
                      case FormElementAttributeTypesFormatTypes.Email:
                          r.Value = ko.observable().extend({
                              required: {
                                  params: n.ValidationLabel,
                                  message: "{0} is a required field.",
                                  onlyIf: function () {
                                      return n.Required();
                                  },
                              },
                              email: { params: n.ValidationLabel, message: "{0} must be a proper email address." },
                          });
                          break;
                      case FormElementAttributeTypesFormatTypes.Number:
                          r.Value = ko.observable().extend({
                              required: {
                                  params: n.ValidationLabel,
                                  message: "{0} is a required field.",
                                  onlyIf: function () {
                                      return n.Required();
                                  },
                              },
                              number: { params: n.ValidationLabel, message: "{0} must be a number." },
                          });
                          break;
                      case FormElementAttributeTypesFormatTypes.Phone:
                          r.Value = ko.observable().extend({
                              required: {
                                  params: n.ValidationLabel,
                                  message: "{0} is a required field.",
                                  onlyIf: function () {
                                      return n.Required();
                                  },
                              },
                              phoneUS: { params: n.ValidationLabel, message: "{0} must be a valid phone number." },
                          });
                          break;
                      default:
                          r.Value = ko.observable().extend({
                              required: {
                                  params: n.ValidationLabel,
                                  message: "{0} is a required field.",
                                  onlyIf: function () {
                                      return n.Required();
                                  },
                              },
                          });
                  }
              } else if (r.ElementType === FormElementTypes.DropdownList)
                  r.Value = ko.observable().extend({
                      required: {
                          params: n.ValidationLabel,
                          message: "{0} is a required field.",
                          onlyIf: function () {
                              return n.Required();
                          },
                      },
                  });
              else if (r.ElementType === FormElementTypes.MultiLineText || r.ElementType === FormElementTypes.RadioButtons)
                  r.Value = ko.observable().extend({
                      required: {
                          params: n.ValidationLabel,
                          message: "{0} is a required field.",
                          onlyIf: function () {
                              return n.Required();
                          },
                      },
                  });
              else if (r.ElementType === FormElementTypes.Signature)
                  r.Value = ko.observable().extend({
                      required: {
                          params: n.ValidationLabel,
                          message: "All Signature fields must be completed before continuing.",
                          onlyIf: function () {
                              return n.Required();
                          },
                      },
                  });
              else if (r.ElementType === FormElementTypes.Date) {
                  var e = FormElementDate.GetDateRangeAttributeValue(n, FormElementAttributeTypes.MinAllowedValue),
                      o = FormElementDate.GetDateRangeAttributeValue(n, FormElementAttributeTypes.MaxAllowedValue),
                      l = e !== null && e.length > 0 && o !== null && o.length > 0,
                      nt = e !== null && e.length > 0 && !l,
                      tt = o !== null && o.length > 0 && !l;
                  r.Value = ko.observable().extend({
                      required: {
                          params: n.ValidationLabel,
                          message: "{0} is a required field.",
                          onlyIf: function () {
                              return n.Required();
                          },
                      },
                      date: { params: n.ValidationLabel, message: "{0} must be a valid date." },
                      DateRangeValidation: {
                          params: [e, o, n.ValidationLabel()],
                          onlyIf: function () {
                              return l && !ko.validation.utils.isEmptyVal(r.Value());
                          },
                          message: "{2} can be no earlier than {0}, and no later than {1}.",
                      },
                      MinDateValidation: {
                          params: [e, n.ValidationLabel()],
                          onlyIf: function () {
                              return nt && !ko.validation.utils.isEmptyVal(r.Value());
                          },
                          message: "{1} can be no earlier than {0}.",
                      },
                      MaxDateValidation: {
                          params: [o, n.ValidationLabel()],
                          onlyIf: function () {
                              return tt && !ko.validation.utils.isEmptyVal(r.Value());
                          },
                          message: "{1} can be no later than {0}.",
                      },
                  });
              } else if (r.ElementType === FormElementTypes.CustomerData) {
                  r.CustomerElementType = n.CustomerElementType();
                  switch (r.CustomerElementType) {
                      case CustomerElementTypes.CustomerFirstName:
                      case CustomerElementTypes.CustomerLastName:
                      case CustomerElementTypes.CustomerCity:
                          r.MaxLength = 50;
                          r.Value = ko.observable().extend({ required: { params: n.ValidationLabel, message: "{0} is a required field." } });
                          break;
                      case CustomerElementTypes.CustomerStateProvince:
                          if (((h = ""), t !== null)) for (s in t.PrepopulateFields) t.PrepopulateFields[s].IntegrationKey === "customer_state" && ((h = t.PrepopulateFields[s].Value), (r.Value = h));
                          r.Value = ko.observable().extend({ required: { params: n.ValidationLabel, message: "State is a required field." } });
                          r.AddCustomerStateSelect(h);
                          break;
                      case CustomerElementTypes.CustomerAddress1:
                          r.MaxLength = 100;
                          r.Value = ko.observable().extend({ required: { params: n.ValidationLabel, message: "{0} is a required field." } });
                          break;
                      case CustomerElementTypes.CustomerAddress2:
                          r.MaxLength = 100;
                          break;
                      case CustomerElementTypes.CustomerPostalCode:
                          if (((r.MaxLength = 20), (c = ""), t !== null)) for (s in t.PrepopulateFields) t.PrepopulateFields[s].IntegrationKey === "customer_country" && ((c = t.PrepopulateFields[s].Value), (r.Value = c));
                          r.Value = ko
                              .observable()
                              .extend({
                                  required: { params: n.ValidationLabel, message: "{0} is a required field." },
                                  postalCodeValid: { params: { formVal: n.ValidationLabel, countryCode: c }, message: "Please specify a valid Postal Code" },
                              });
                          break;
                      case CustomerElementTypes.CustomerCountry:
                          r.MaxLength = 3;
                          r.Value = ko.observable().extend({ required: { params: n.ValidationLabel, message: "{0} is a required field." } });
                          break;
                      case CustomerElementTypes.CustomerEmailAddress:
                          r.MaxLength = 250;
                          r.Value = ko.observable().extend({ required: { params: n.ValidationLabel, message: "{0} is a required field." }, email: !0 });
                          break;
                      case CustomerElementTypes.DaytimePhone:
                      case CustomerElementTypes.EveningPhone:
                      case CustomerElementTypes.MobilePhone:
                          r.MaxLength = 50;
                          r.Value = i.FeatureFlag().enableInternationalPhoneValidation
                              ? ko.observable().extend({
                                    required: {
                                        params: n.ValidationLabel,
                                        message: "{0} is a required field.",
                                        onlyIf: function () {
                                            return n.Required();
                                        },
                                    },
                                    phoneUSAndInternationalNoExt: {
                                        message: n.Text() + " must be a valid phone number.",
                                        params: { phoneNo: n.ValidationLabel, eleName: n.Text() },
                                        onlyIf: function () {
                                            return !0;
                                        },
                                    },
                                })
                              : ko.observable().extend({
                                    required: {
                                        params: n.ValidationLabel,
                                        message: "{0} is a required field.",
                                        onlyIf: function () {
                                            return n.Required();
                                        },
                                    },
                                    phoneUSNoExt: {
                                        message: "{0} must be a valid phone number.",
                                        params: n.ValidationLabel,
                                        onlyIf: function () {
                                            return i.InstCountry === CountryCode.USA;
                                        },
                                    },
                                });
                          break;
                      case CustomerElementTypes.PrimaryPersonId:
                          var k = FormElementCustomerData.GetPrimaryPersonIdAttributeValue(n, FormElementAttributeTypes.PrimaryPersonIdSpecialFormat),
                              d = 0,
                              a = 100,
                              v = PrimaryPersonIdCharacterTypes.Combination;
                          r.MaxLength = a;
                          k === PrimaryPersonIdSpecialFormatTypes.CharacterLimit.toString()
                              ? ((d = Number(FormElementCustomerData.GetPrimaryPersonIdAttributeValue(n, FormElementAttributeTypes.PrimaryPersonIdMinCharacters))),
                                (a = Number(FormElementCustomerData.GetPrimaryPersonIdAttributeValue(n, FormElementAttributeTypes.PrimaryPersonIdMaxCharacters))),
                                (v = Number(FormElementCustomerData.GetPrimaryPersonIdAttributeValue(n, FormElementAttributeTypes.PrimaryPersonIdCharacterType))),
                                (r.Value = ko.observable().extend({
                                    required: {
                                        message: "ID is a required field.",
                                        onlyIf: function () {
                                            return n.Required();
                                        },
                                    },
                                    pattern: {
                                        message: "ID can only contain alpha characters",
                                        params: /^[A-Za-z]+$/,
                                        onlyIf: function () {
                                            return v === PrimaryPersonIdCharacterTypes.Alpha;
                                        },
                                    },
                                    digit: {
                                        message: "ID can only contain numeric characters",
                                        onlyIf: function () {
                                            return v === PrimaryPersonIdCharacterTypes.Numeric;
                                        },
                                    },
                                    minLength: { params: d, message: "ID must be at least {0} characters" },
                                    maxLength: { params: a, message: "ID cannot be more than {0} characters" },
                                })))
                              : k === PrimaryPersonIdSpecialFormatTypes.DefinedFormat.toString()
                              ? ((g = FormElementCustomerData.GetPrimaryPersonIdAttributeValue(n, FormElementAttributeTypes.PrimaryPersonIdRegex)),
                                r.Value.extend({
                                    required: {
                                        message: "ID is a required field.",
                                        onlyIf: function () {
                                            return n.Required();
                                        },
                                    },
                                    pattern: { message: "ID is not in the correct format", params: g },
                                }),
                                (r.HelpText = FormElementCustomerData.GetPrimaryPersonIdAttributeValue(n, FormElementAttributeTypes.PrimaryPersonIdHelpText)))
                              : r.Value.extend({
                                    required: {
                                        message: "ID is a required field.",
                                        onlyIf: function () {
                                            return n.Required();
                                        },
                                    },
                                });
                  }
              }
              return r;
          };
          this.PrepopulateCustomerFacingElements = function (n, t) {
              var u, i, r;
              n.forEach(function (n) {
                  var i = ko.utils.arrayFilter(t.PrepopulateFields, function (t) {
                      return t.FormElementId === n.ElementId;
                  });
                  if (i && i.length > 0)
                      switch (n.ElementType) {
                          case FormElementTypes.Product:
                              i.forEach(function (t) {
                                  var r = !1,
                                      i = ko.utils.arrayFirst(n.Options, function (n) {
                                          return n.Value === t.FormElementOptionId;
                                      }),
                                      u;
                                  i &&
                                      (i.HasConsumerEnteredPrice && t.Price > 0 ? (i.Selected(!0), i.Price.Amount(t.Price), (r = !0)) : t.Quantity > 0 && (i.Selected(!0), i.Quantity(t.Quantity), (r = !0)),
                                      t.Hidden && n.Hidden(!0),
                                      t.ReadOnly && n.ReadOnly(!0));
                                  r && (+n.Attributes[0].Value === ProductDisplayType.CheckboxCollection ? n.Value.push(i) : ((u = i.Quantity()), n.Value(i), i.Quantity(u)));
                              });
                              break;
                          case FormElementTypes.SingleLineText:
                          case FormElementTypes.MultiLineText:
                              n.Value(i[0].Value);
                              n.Hidden(i[0].Hidden);
                              n.ReadOnly(i[0].ReadOnly);
                              break;
                          case FormElementTypes.Checkboxes:
                              i.forEach(function (t) {
                                  n.Value.push(t.FormElementOptionId);
                                  t.Hidden && n.Hidden(!0);
                                  t.ReadOnly && n.ReadOnly(!0);
                              });
                              break;
                          case FormElementTypes.DropdownList:
                          case FormElementTypes.RadioButtons:
                              i[0].FormElementOptionId && n.Value(i[0].FormElementOptionId);
                              n.Hidden(i[0].Hidden);
                              n.ReadOnly(i[0].ReadOnly);
                              break;
                          case FormElementTypes.Date:
                              n.Value(i[0].Value);
                              n.Hidden(i[0].Hidden);
                              n.ReadOnly(i[0].ReadOnly);
                              break;
                          case FormElementTypes.CustomerData:
                              switch (n.CustomerElementType) {
                                  case CustomerElementTypes.CustomerStateProvince:
                                      n.Value(i[0].Value);
                                      n.CustomerStateSelect(i[0].Value);
                                      n.Hidden(i[0].Hidden);
                                      n.ReadOnly(i[0].ReadOnly);
                                      break;
                                  case CustomerElementTypes.CustomerCountry:
                                      n.Value(i[0].Value);
                                      n.Hidden(i[0].Hidden);
                                      n.ReadOnly(i[0].ReadOnly);
                                      break;
                                  default:
                                      n.Value(i[0].Value);
                                      n.Hidden(i[0].Hidden);
                                      n.ReadOnly(i[0].ReadOnly);
                              }
                      }
              });
              u = ko.utils.arrayFilter(n, function (n) {
                  return n.ElementType === FormElementTypes.Product && n.ReadOnly();
              });
              u.forEach(function (n) {
                  n.Options.forEach(function (t) {
                      t.ReadOnly(n.ReadOnly());
                  });
              });
              i = ko.utils.arrayFirst(n, function (n) {
                  return n.ElementType === FormElementTypes.CustomerData && n.CustomerElementType === CustomerElementTypes.PrimaryPersonId;
              });
              i &&
                  ((r = ko.utils.arrayFirst(n, function (n) {
                      return n.ElementType === FormElementTypes.CustomerData && n.CustomerElementType === CustomerElementTypes.ConfirmPrimaryPersonId;
                  })),
                  r && (r.Value(i.Value()), r.Hidden(i.Hidden()), r.ReadOnly(i.ReadOnly())));
          };
          this.HydrateDefinition = function (t, i, r) {
              var u = new FormDefinition(),
                  f = [];
              return (
                  (u.FormId = t.Id),
                  (u.FormTitle = t.FormTitle),
                  (u.CollectPayments = t.CollectPayments),
                  (u.IsActive = t.IsActive),
                  (u.AllowPrepopulate = t.AllowPrepopulate),
                  (u.CallRtdd = t.CallRtdd),
                  t.AvailableTerms &&
                      t.AvailableTerms.forEach(function (n) {
                          var t = new Term();
                          t.Accounts = [];
                          t.AdjustmentReasons = [];
                          t.Name = n.Name;
                          t.Code = n.Code;
                          t.Key = n.Key;
                          n.Accounts != null &&
                              n.Accounts.forEach(function (n) {
                                  var i = new InstAccount();
                                  i.Name = n.Name;
                                  i.Code = n.Code;
                                  i.EPayProfileId = n.EPayProfileId;
                                  i.Suppressed = n.Suppressed;
                                  t.Accounts.push(i);
                              });
                          n.AdjustmentReasons != null &&
                              n.AdjustmentReasons.forEach(function (n) {
                                  var i = new AdjustmentReason();
                                  i.Code = n.Code;
                                  i.Reason = n.Reason;
                                  i.TransactionType = n.TransactionType;
                                  t.AdjustmentReasons.push(i);
                              });
                          u.AvailableTerms.push(t);
                      }),
                  t.FormTerms != null &&
                      (t.FormTerms.forEach(function (n) {
                          var t = new FormTerm(u.AvailableTerms);
                          t.Id = n.Id;
                          t.TermCode(n.TermCode);
                          t.OriginalTermCode = n.TermCode;
                          t.TermKey(n.TermKey);
                          t.HideTerm(n.HideTerm);
                          n.FormAccounts &&
                              n.FormAccounts.forEach(function (n) {
                                  var i = new FormAccount();
                                  i.Id = n.Id;
                                  i.AccountCode(n.AccountCode);
                                  i.AdjustmentCode(n.AdjustmentCode);
                                  i.Text = n.Text;
                                  i.AssignedToProduct(n.AssignedToProduct);
                                  t.FormAccounts.push(i);
                                  f.push(n.AccountCode);
                              });
                          t.AssignedToProduct(
                              ko.utils.arrayFirst(t.FormAccounts(), function (n) {
                                  return n.AssignedToProduct();
                              }) != null
                          );
                          u.FormTerms.push(t);
                      }),
                      n.PopulateTermNames(u.FormTerms, u.AvailableTerms)),
                  u.AvailableTerms &&
                      u.FormTerms &&
                      u.AvailableTerms.forEach(function (n) {
                          n.Accounts !== null &&
                              n.Accounts.forEach(function (n) {
                                  ko.utils.arrayFirst(f, function (t) {
                                      return t === n.Code;
                                  }) !== null && (n.AvailableForInst = !0);
                              });
                      }),
                  t.FormElements !== null &&
                      t.FormElements.forEach(function (n) {
                          var i = new FormElement(r, n.DisplayOrder),
                              f;
                          i.Id = n.Id;
                          i.AllowMultiPurchase(n.AllowMultiPurchase);
                          i.AllowQuantityPurchase(n.AllowQuantityPurchase);
                          i.SetPricing = ko.observable(n.SetPricing);
                          i.TrackInventory = ko.observable(n.TrackInventory);
                          i.Text(n.Text);
                          i.Required(n.Required);
                          i.ElementType = ko.observable(n.ElementType);
                          i.ShortDescription(n.ShortDescription);
                          n.FormElementOptions !== null &&
                              n.FormElementOptions.forEach(function (n) {
                                  var t = new FormElementOption(i);
                                  t.Id = n.Id;
                                  t.InventoryId = n.InventoryId;
                                  t.Name(n.Name);
                                  t.InventoryOriginalQuantityAvailable(n.InventoryOriginalQuantityAvailable);
                                  t.Price(n.Price);
                                  t.InventoryCurrentQuantityAvailable = n.InventoryCurrentQuantityAvailable;
                                  t.InventoryTransactionTotal(n.InventoryTransactionTotal);
                                  t.ConsumerEnteredPrice(n.ConsumerEnteredPrice);
                                  t.MaxPrice(n.MaxPrice);
                                  t.MinPrice(n.MinPrice);
                                  i.FormElementOptions.push(t);
                              });
                          n.FormElementAttributes !== null &&
                              n.FormElementAttributes.forEach(function (n) {
                                  var t = new FormElementAttribute();
                                  t.Id = n.Id;
                                  t.AttributeType(n.AttributeType);
                                  t.Value(n.Value);
                                  i.FormElementAttributes.push(t);
                              });
                          n.ElementType == FormElementTypes.Product &&
                              t.SalesTaxes !== null &&
                              t.SalesTaxes.forEach(function (t) {
                                  var r = new FormElementSalesTaxOption(),
                                      u;
                                  r.SalesTaxId = t.Id;
                                  r.FormElementId = n.Id;
                                  r.Name = t.Name;
                                  r.Percentage = t.Percentage;
                                  u =
                                      ko.utils.arrayFirst(n.FormElementSalesTaxes, function (n) {
                                          return n.SalesTaxId === r.SalesTaxId;
                                      }) !== null;
                                  r.Selected(u);
                                  i.FormElementSalesTaxOptions.push(r);
                              });
                          n.FormElementSalesTaxes !== null &&
                              n.FormElementSalesTaxes.forEach(function (n) {
                                  var t = new FormElementSalesTax();
                                  t.Id = n.Id;
                                  t.SalesTaxId = n.SalesTaxId;
                                  t.FormElementId = n.FormElementId;
                                  i.FormElementSalesTaxes.push(t);
                                  i.ApplySalesTax("yes");
                              });
                          n.FormElementAccounts !== null &&
                              n.FormElementAccounts.sort(function (n, t) {
                                  return n.FormTermId > t.FormTermId ? 1 : -1;
                              }).forEach(function (n) {
                                  var t = new FormElementAccount(u.FormTerms(), i, n.FormAccountId);
                                  t.Id = n.Id;
                                  t.FormElementId = n.FormElementId;
                                  t.FormTermId = n.FormTermId;
                                  i.FormElementAccounts.push(t);
                              });
                          n.ElementType == FormElementTypes.Date && n.FormElementAttributes.length > 0 ? i.AddDateValueRestriction(!0) : i.AddDateValueRestriction(!1);
                          n.ElementType == FormElementTypes.Signature &&
                              n.FormElementAttributes.length > 0 &&
                              ((f = ko.utils.arrayFirst(n.FormElementAttributes, function (n) {
                                  return n.AttributeType === FormElementAttributeTypes.ElementValueEntryOption;
                              })),
                              f != null && (f.Value == SignatureTypeEnum.None.toString() ? i.SignatureElementValueEntryOption(!1) : i.SignatureElementValueEntryOption(!0)));
                          u.FormElements.push(i);
                      }),
                  t.MessageRecipients !== null &&
                      t.MessageRecipients.forEach(function (n) {
                          var t = new MessageRecipient();
                          t.Id = n.Id;
                          t.Address(n.Address);
                          u.MessageRecipients.push(t);
                      }),
                  t.SalesTaxes !== null &&
                      t.SalesTaxes.forEach(function (n) {
                          var t = new SalesTax();
                          t.Id = n.Id;
                          t.Name(n.Name);
                          t.AccountCode(n.AccountCode);
                          t.AdjustmentCode(n.AdjustmentCode);
                          t.Percentage(n.Percentage);
                          u.SalesTaxes.push(t);
                      }),
                  u
              );
          };
          this.PopulateTermNames = function (n, t) {
              n &&
                  n().forEach(function (n) {
                      var i = ko.utils.arrayFirst(t, function (t) {
                          return t.Code === n.TermCode();
                      });
                      i && (n.TermName = i.Name);
                  });
          };
      }
      return n;
  })(),
  FormAccessViewModel = (function () {
      function n(n, t, i, r) {
          this.FixSelectsForIos = function () {
              navigator.userAgent.match(/(iPod|iPhone)/) && $("select.form-control").append('<optgroup label=""></optgroup>');
          };
          var u = new ElementMapperEngine(),
              f = u.HydrateDefinition(n, null, null);
          this.FeatureFlag = ko.observable(r);
          this.FormDefinition = ko.observable(f);
          this.StatePassThrough = i === null ? [] : i.PrepopulateFields;
          this.FormDisplay = new CustomerFormViewModel(this.FormDefinition, t, i, this.FeatureFlag);
      }
      return n;
  })(),
  FormBuilderViewModel = (function () {
      function n(n, t, i, r) {
          var u = this,
              f,
              e,
              o,
              s;
          if (
              ((this.FormTitle = ko.observable("")),
              (this.Saving = ko.observable(!1)),
              (this.FormTerms = Array()),
              (this.FormDefSalesTaxes = Array()),
              (this.PrimaryPersonLabel = ko.observable("")),
              (this.InstitutionTermsHeaderEdit = ko.observable("")),
              (this.InstitutionTermsEdit = ko.observable("")),
              (this.AddFormElement = function () {
                  var n = new FormElement(u.DeletedFormElementOptions, u.NextDisplayOrder());
                  return u.FormElements.push(n), u.HasSignatureElement() && u.SortAndResequenceElementsWithSignature(), n;
              }),
              (this.AddHeading = function () {
                  u.FormElements.push(new FormHeading(u.DeletedFormElementOptions, u.NextDisplayOrder()));
                  u.HasSignatureElement() && u.SortAndResequenceElementsWithSignature();
              }),
              (this.AddImage = function () {
                  u.FormElements.push(new FormImage(u.DeletedFormElementOptions, u.NextDisplayOrder()));
                  u.HasSignatureElement() && u.SortAndResequenceElementsWithSignature();
              }),
              (this.AddParagraph = function () {
                  u.FormElements.push(new FormParagraph(u.DeletedFormElementOptions, u.NextDisplayOrder()));
                  u.HasSignatureElement() && u.SortAndResequenceElementsWithSignature();
              }),
              (this.AddProduct = function () {
                  var n = new FormProduct(u.DeletedFormElementOptions, u.NextDisplayOrder(), u.FormTerms);
                  return (
                      u.FormTerms &&
                          u.FormTerms.length > 0 &&
                          (u.FormTerms.forEach(function (t) {
                              var i = new FormElementAccount(u.FormTerms, n);
                              i.FormTermId = t.Id;
                              n.FormElementAccounts.push(i);
                          }),
                          u.HasMultipleTermsOrAccounts || n.FormElementAccounts()[0].FormAccountId(u.FormTerms[0].FormAccounts()[0].Id)),
                      u.HasSalesTax &&
                          u.FormDefSalesTaxes.forEach(function (t) {
                              var i = new FormElementSalesTaxOption();
                              i.SalesTaxId = t.Id;
                              i.Name = t.Name();
                              i.Percentage = t.Percentage();
                              i.Selected(!1);
                              n.FormElementSalesTaxOptions.push(i);
                          }),
                      u.FormElements.push(n),
                      u.HasSignatureElement() && u.SortAndResequenceElementsWithSignature(),
                      n
                  );
              }),
              (this.AddCustomerDataElement = function () {
                  if (!u.HasCustomerDataElement()) {
                      var n = FormElementCustomerData.AddCustomerLabelField(u.FormElements, u.InstitutionInfo.PrimaryPersonLabel, u.DeletedFormElementOptions, u.NextDisplayOrder());
                      FormElementCustomerData.AddCustomerNameFields(u.FormElements, u.DeletedFormElementOptions, u.NextDisplayOrder());
                      u.CallRtddEnabled && ((u.AllowPrimaryPersonIdSelect = !1), FormElementCustomerData.AddPrimaryPersonIdField(u.FormElements, u.DeletedFormElementOptions, u.NextDisplayOrder()));
                      n.Text.subscribe(function (n) {
                          u.PrimaryPersonLabel(n);
                      });
                      u.HasSignatureElement() && u.SortAndResequenceElementsWithSignature();
                  }
              }),
              (this.DisplaySignatureElementWarning = function () {
                  u.HasSignatureElement() || ($("#acknowledgeCapabilities").prop("checked", !1), $("#modalAcknowledgeESignatureInformation").prop("disabled", !0), $("#modalESignInformation").modal("show"));
              }),
              (this.AddSignatureElement = function () {
                  u.HasSignatureElement() || u.FormElements.push(new FormElementSignature(u.InstitutionInfo.Name, u.DeletedFormElementOptions, u.NextDisplayOrder()));
              }),
              (this.CopyFormElement = function (n) {
                  var t;
                  t = n.ElementType() === FormElementTypes.Product ? u.AddProduct() : u.AddFormElement();
                  u.MoveElement(t, n.DisplayOrder() + 1);
                  u.StopMove(t);
                  t.Text("Copy - " + n.Text());
                  t.ElementType(n.ElementType());
                  t.Required(n.Required());
                  t.AllowMultiPurchase(n.AllowMultiPurchase());
                  t.AllowQuantityPurchase(n.AllowQuantityPurchase());
                  t.SetPricing(n.SetPricing());
                  t.TrackInventory(n.TrackInventory());
                  t.ApplySalesTax(n.ApplySalesTax());
                  n.FormElementAttributes() != null &&
                      n.FormElementAttributes().forEach(function (n) {
                          var i = new FormElementAttribute();
                          i.AttributeType(n.AttributeType());
                          n.AttributeType() === FormElementAttributeTypes.ProductDisplayType || n.AttributeType() === FormElementAttributeTypes.FormatType
                              ? ((i = ko.utils.arrayFirst(t.FormElementAttributes(), function (t) {
                                    return t.AttributeType() === n.AttributeType();
                                })),
                                i.Value(n.Value()))
                              : n.AttributeType() === FormElementAttributeTypes.ImageToken
                              ? (u.CopyImageAttribute(n.Value(), i), t.FormElementAttributes.push(i))
                              : (i.Value(n.Value()), t.FormElementAttributes.push(i));
                      });
                  n.FormElementOptions() != null &&
                      n.FormElementOptions().forEach(function (n) {
                          if (!n.Deleted()) {
                              var i = t.AddOption();
                              i.AllowQuantityPurchase(n.AllowQuantityPurchase());
                              i.ConsumerEnteredPrice(n.ConsumerEnteredPrice());
                              i.InventoryOriginalQuantityAvailable(n.InventoryOriginalQuantityAvailable());
                              i.Price(n.Price());
                              i.MaxPrice(n.MaxPrice());
                              i.MinPrice(n.MinPrice());
                              i.Name(n.Name());
                          }
                      });
                  n.FormElementSalesTaxes() != null &&
                      n.FormElementSalesTaxes().forEach(function (n) {
                          var i = new FormElementSalesTax(),
                              r;
                          i.FormElementId = t.Id;
                          i.SalesTaxId = n.SalesTaxId;
                          t.FormElementSalesTaxes.push(i);
                          r = ko.utils.arrayFirst(t.FormElementSalesTaxOptions(), function (t) {
                              return t.SalesTaxId === n.SalesTaxId;
                          });
                          r !== null && r.Selected(!0);
                      });
              }),
              (this.RemoveFormElement = function (n) {
                  n.FormElementOptions != null &&
                      n.FormElementOptions().forEach(function (n) {
                          n.Deleted(!0);
                      });
                  u.FormElements.remove(n);
                  n.Id !== 0 && u.DeletedFormElements.push(n.Id);
              }),
              (this.RemoveCustomerFormElement = function (n) {
                  u.RemoveFormElement(n);
                  u.RemoveCustomerNameFields();
                  u.RemoveCustomerAddressFields();
                  u.RemoveCustomerField(CustomerElementTypes.CustomerEmailAddress);
                  u.RemoveCustomerField(CustomerElementTypes.DaytimePhone);
                  u.RemoveCustomerField(CustomerElementTypes.EveningPhone);
                  u.RemoveCustomerField(CustomerElementTypes.MobilePhone);
                  u.RemoveCustomerPrimaryPersonIdField();
              }),
              (this.StartMove = function (n) {
                  n.Moving(!0);
                  u.ConfigureQuickMove(n, !0);
              }),
              (this.StopMove = function (n) {
                  n.Moving(!1);
                  u.ConfigureQuickMove(n, !1);
              }),
              (this.ConfigureQuickMove = function (n, t) {
                  var r, i;
                  if (!t) {
                      u.FormElements().forEach(function (n) {
                          n.ShowMoveAbove(!1);
                          n.ShowMoveBelow(!1);
                      });
                      return;
                  }
                  r = ko.utils.arrayFirst(u.FormElements(), function (t) {
                      return t.DisplayOrder() === n.DisplayOrder() + 1;
                  });
                  t &&
                      u.FormElements().forEach(function (t) {
                          t === n || t === r ? t.ShowMoveAbove(!1) : t.ShowMoveAbove(!0);
                      });
                  u.FormElements().forEach(function (n) {
                      n.ShowMoveBelow(!1);
                  });
                  i = u.FormElements().reduce(function (n, t) {
                      return n.DisplayOrder() > t.DisplayOrder() ? n : t;
                  });
                  i !== null && i !== n && i.ElementType() !== FormElementTypes.Signature && i.ShowMoveBelow(!0);
              }),
              (this.MoveAbove = function (n) {
                  var t = ko.utils.arrayFirst(u.FormElements(), function (n) {
                          return n.Moving() === !0;
                      }),
                      i = n.DisplayOrder();
                  u.MoveElement(t, i);
              }),
              (this.MoveBelow = function (n) {
                  var t = ko.utils.arrayFirst(u.FormElements(), function (n) {
                          return n.Moving() === !0;
                      }),
                      i = n.DisplayOrder() + 1;
                  u.MoveElement(t, i);
              }),
              (this.MoveUp = function (n) {
                  var t = n.DisplayOrder() - 1;
                  u.SwapElements(n, t);
              }),
              (this.MoveDown = function (n) {
                  var t = u.GetNewIndexForMoveDown(n);
                  u.SwapElements(n, t);
              }),
              (this.GetNewIndexForMoveDown = function (n) {
                  return n.CustomerElementType() === CustomerElementTypes.CustomerLabel ? u.GetLastCustomerElement().DisplayOrder() + 1 : n.DisplayOrder() + 1;
              }),
              (this.GetLastCustomerElement = function () {
                  var n = ko.utils.arrayFirst(u.FormElements(), function (n) {
                      return n.CustomerElementType() === CustomerElementTypes.PrimaryPersonId;
                  });
                  return (
                      n === null &&
                          (n = ko.utils.arrayFirst(u.FormElements(), function (n) {
                              return n.CustomerElementType() === CustomerElementTypes.MobilePhone;
                          })),
                      n === null &&
                          (n = ko.utils.arrayFirst(u.FormElements(), function (n) {
                              return n.CustomerElementType() === CustomerElementTypes.EveningPhone;
                          })),
                      n === null &&
                          (n = ko.utils.arrayFirst(u.FormElements(), function (n) {
                              return n.CustomerElementType() === CustomerElementTypes.DaytimePhone;
                          })),
                      n === null &&
                          (n = ko.utils.arrayFirst(u.FormElements(), function (n) {
                              return n.CustomerElementType() === CustomerElementTypes.CustomerEmailAddress;
                          })),
                      n === null &&
                          (n = ko.utils.arrayFirst(u.FormElements(), function (n) {
                              return n.CustomerElementType() === CustomerElementTypes.CustomerPostalCode;
                          })),
                      n === null &&
                          (n = ko.utils.arrayFirst(u.FormElements(), function (n) {
                              return n.CustomerElementType() === CustomerElementTypes.CustomerLastName;
                          })),
                      n
                  );
              }),
              (this.MoveElement = function (n, t) {
                  n !== null &&
                      (n.DisplayOrder(t),
                      u.FormElements().forEach(function (i) {
                          i.DisplayOrder() >= t && i != n && i.DisplayOrder(i.DisplayOrder() + 1);
                      }),
                      u.AfterMove(n, !0));
              }),
              (this.SwapElements = function (n, t) {
                  var r = n.DisplayOrder(),
                      i = ko.utils.arrayFirst(u.FormElements(), function (n) {
                          return n.DisplayOrder() == t;
                      });
                  i !== null && (i.DisplayOrder(r), n.DisplayOrder(t), u.AfterMove(n, !0));
              }),
              (this.AfterMove = function (n, t) {
                  u.SortAndResequenceElements();
                  u.ResequenceCustomerDataElements();
                  u.ConfigureQuickMove(n, t);
              }),
              (this.SortAndResequenceElementsWithSignature = function () {
                  var n = ko.utils.arrayFirst(u.FormElements(), function (n) {
                      return n.ElementType() == FormElementTypes.Signature;
                  });
                  n.DisplayOrder(u.FormElements().length * 2);
                  u.SortAndResequenceElements();
              }),
              (this.SortAndResequenceElements = function () {
                  u.SortElements();
                  u.ResequenceElements();
              }),
              (this.SortElements = function () {
                  u.FormElements.sort(function (n, t) {
                      return n.DisplayOrder() - t.DisplayOrder();
                  });
              }),
              (this.ResequenceElements = function () {
                  if (u.FormElements() !== null) {
                      var n = 0;
                      u.FormElements().forEach(function (t) {
                          t.DisplayOrder(++n);
                      });
                  }
              }),
              (this.ResequenceCustomerDataElements = function () {
                  var t = ko.utils.arrayFirst(u.FormElements(), function (n) {
                          return n.CustomerElementType() == CustomerElementTypes.CustomerLabel;
                      }),
                      n;
                  t !== null &&
                      ((n = t.DisplayOrder() + 1),
                      (n = u.MoveCustomerDataElement(CustomerElementTypes.CustomerFirstName, n)),
                      (n = u.MoveCustomerDataElement(CustomerElementTypes.CustomerLastName, n)),
                      (n = u.MoveCustomerDataElement(CustomerElementTypes.CustomerCountry, n)),
                      (n = u.MoveCustomerDataElement(CustomerElementTypes.CustomerAddress1, n)),
                      (n = u.MoveCustomerDataElement(CustomerElementTypes.CustomerAddress2, n)),
                      (n = u.MoveCustomerDataElement(CustomerElementTypes.CustomerCity, n)),
                      (n = u.MoveCustomerDataElement(CustomerElementTypes.CustomerStateProvince, n)),
                      (n = u.MoveCustomerDataElement(CustomerElementTypes.CustomerPostalCode, n)),
                      (n = u.MoveCustomerDataElement(CustomerElementTypes.CustomerEmailAddress, n)),
                      (n = u.MoveCustomerDataElement(CustomerElementTypes.DaytimePhone, n)),
                      (n = u.MoveCustomerDataElement(CustomerElementTypes.EveningPhone, n)),
                      (n = u.MoveCustomerDataElement(CustomerElementTypes.MobilePhone, n)),
                      (n = u.MoveCustomerDataElement(CustomerElementTypes.PrimaryPersonId, n)));
                  u.SortAndResequenceElements();
              }),
              (this.MoveCustomerDataElement = function (n, t) {
                  var i = ko.utils.arrayFirst(u.FormElements(), function (t) {
                      return t.CustomerElementType() === n;
                  });
                  return i !== null
                      ? (i.DisplayOrder(t),
                        u.FormElements().forEach(function (n) {
                            n.DisplayOrder() >= t && n != i && n.DisplayOrder(n.DisplayOrder() + 1);
                        }),
                        t + 1)
                      : t;
              }),
              (this.NextDisplayOrder = function () {
                  if (u.FormElements().length > 0) {
                      var n = u.FormElements().reduce(function (n, t) {
                          return n.DisplayOrder() > t.DisplayOrder() ? n : t;
                      });
                      return n.DisplayOrder() + 1;
                  }
                  return 1;
              }),
              (this.CurrentMovingElement = function () {
                  return ko.utils.arrayFirst(u.FormElements(), function (n) {
                      return n.Moving() === !0;
                  });
              }),
              (this.HasCustomerDataElement = function () {
                  return u.HasCustomerElement(CustomerElementTypes.CustomerLabel);
              }),
              (this.HasCustomerPostalAddressElements = function () {
                  return u.HasCustomerElement(CustomerElementTypes.CustomerAddress1);
              }),
              (this.HasCustomerEmailAddressElement = function () {
                  return u.HasCustomerElement(CustomerElementTypes.CustomerEmailAddress);
              }),
              (this.HasDaytimePhoneElement = function () {
                  return u.HasCustomerElement(CustomerElementTypes.DaytimePhone);
              }),
              (this.HasEveningPhoneElement = function () {
                  return u.HasCustomerElement(CustomerElementTypes.EveningPhone);
              }),
              (this.HasMobilePhoneElement = function () {
                  return u.HasCustomerElement(CustomerElementTypes.MobilePhone);
              }),
              (this.HasPrimaryPersonIdElement = function () {
                  return u.HasCustomerElement(CustomerElementTypes.PrimaryPersonId);
              }),
              (this.HasCustomerElement = function (n) {
                  return (
                      ko.utils.arrayFirst(u.FormElements(), function (t) {
                          return t.CustomerElementType() === n;
                      }) !== null
                  );
              }),
              (this.HasSignatureElement = function () {
                  return (
                      ko.utils.arrayFirst(u.FormElements(), function (n) {
                          return n.ElementType() === FormElementTypes.Signature;
                      }) !== null
                  );
              }),
              (this.CustomerPostalAddressChanged = function () {
                  return (
                      u.HasCustomerPostalAddressElements() ? u.RemoveCustomerAddressFields() : FormElementCustomerData.AddCustomerAddressFields(u.FormElements, u.DeletedFormElementOptions, u.NextDisplayOrder()),
                      u.ResequenceCustomerDataElements(),
                      !0
                  );
              }),
              (this.CustomerEmailAddressChanged = function () {
                  return u.CustomerElementChanged(CustomerElementTypes.CustomerEmailAddress);
              }),
              (this.DaytimePhoneChanged = function () {
                  return u.CustomerElementChanged(CustomerElementTypes.DaytimePhone);
              }),
              (this.EveningPhoneChanged = function () {
                  return u.CustomerElementChanged(CustomerElementTypes.EveningPhone);
              }),
              (this.MobilePhoneChanged = function () {
                  return u.CustomerElementChanged(CustomerElementTypes.MobilePhone);
              }),
              (this.PrimaryPersonIdChanged = function () {
                  return (
                      u.HasPrimaryPersonIdElement()
                          ? u.RemoveCustomerPrimaryPersonIdField()
                          : (FormElementCustomerData.AddPrimaryPersonIdField(u.FormElements, u.DeletedFormElementOptions, u.NextDisplayOrder()), u.CallRtddEnabled && (u.AllowPrimaryPersonIdSelect = !1)),
                      u.ResequenceCustomerDataElements(),
                      !0
                  );
              }),
              (this.CustomerElementChanged = function (n) {
                  return u.HasCustomerElement(n) ? u.RemoveCustomerField(n) : FormElementCustomerData.AddCustomerField(n, u.FormElements, u.DeletedFormElementOptions, u.NextDisplayOrder()), u.ResequenceCustomerDataElements(), !0;
              }),
              (this.RemoveCustomerNameFields = function () {
                  u.RemoveCustomerField(CustomerElementTypes.CustomerFirstName);
                  u.RemoveCustomerField(CustomerElementTypes.CustomerLastName);
              }),
              (this.RemoveCustomerAddressFields = function () {
                  u.RemoveCustomerField(CustomerElementTypes.CustomerAddress1);
                  u.RemoveCustomerField(CustomerElementTypes.CustomerAddress2);
                  u.RemoveCustomerField(CustomerElementTypes.CustomerCity);
                  u.RemoveCustomerField(CustomerElementTypes.CustomerStateProvince);
                  u.RemoveCustomerField(CustomerElementTypes.CustomerPostalCode);
                  u.RemoveCustomerField(CustomerElementTypes.CustomerCountry);
              }),
              (this.RemoveCustomerPrimaryPersonIdField = function () {
                  FormElementCustomerData.RemovePrimaryPersonIdAttributes(u.PrimaryPersonIdElement);
                  u.RemoveCustomerField(CustomerElementTypes.PrimaryPersonId);
              }),
              (this.RemoveCustomerField = function (n) {
                  var t = ko.utils.arrayFilter(u.FormElements(), function (n) {
                      return n.ElementType() === FormElementTypes.CustomerData;
                  });
                  t.forEach(function (t) {
                      t.CustomerElementType() === n && u.RemoveFormElement(t);
                  });
              }),
              (this.PrimaryPersonIdCharacterLimitSelected = function () {
                  return FormElementCustomerData.RemovePrimaryPersonSpecialFormatAttributes(u.PrimaryPersonIdElement), FormElementCustomerData.AddPrimaryPersonCharacterLimitAttributes(u.PrimaryPersonIdElement), !0;
              }),
              (this.PrimaryPersonIdDefinedFormatSelected = function () {
                  return FormElementCustomerData.RemovePrimaryPersonSpecialFormatAttributes(u.PrimaryPersonIdElement), FormElementCustomerData.AddPrimaryPersonDefinedFormatAttributes(u.PrimaryPersonIdElement), !0;
              }),
              (this.PrimaryPersonIdSpecialFormatRemoved = function () {
                  return FormElementCustomerData.RemovePrimaryPersonSpecialFormatAttributes(u.PrimaryPersonIdElement), !0;
              }),
              (this.Submit = function () {
                  u.CallRtddEnabled ? u.ValidateRtddInformationPresent() && u.ValidateAndSave(!1) : u.ValidateAndSave(!1);
              }),
              (this.Publish = function () {
                  u.CallRtddEnabled ? u.ValidateRtddInformationPresent() && u.ValidateAllTermsNotHidden() && u.ValidateAndSave(!0) : u.ValidateAllTermsNotHidden() && u.ValidateAndSave(!0);
              }),
              (this.ValidateAndSave = function (n) {
                  u.Errors().length > 0 ? (u.Errors.showAllMessages(!0), window.scrollTo(0, 0)) : (u.Saving(!0), n && (u.Activate = !0), u.UpdateForm());
              }),
              (this.ValidateAllTermsNotHidden = function () {
                  var n = !0,
                      i = ko.utils.arrayFilter(u.FormElements(), function (n) {
                          return n.ElementType() === FormElementTypes.Product && n.SetPricing();
                      }),
                      t;
                  return (
                      i.length > 0 &&
                          ((t = ko.utils.arrayFilter(u.FormTerms, function (n) {
                              return !n.HideTerm();
                          })),
                          t.length === 0 && ((n = !1), $("#modalWarnAndConfirmSave").modal("show"))),
                      n
                  );
              }),
              (this.ValidateRegexFormat = function () {
                  var n = u.PrimaryPersonIdRegex;
                  if (n)
                      try {
                          new RegExp(n());
                      } catch (t) {
                          return !1;
                      }
                  return !0;
              }),
              (this.ValidateRtddInformationPresent = function () {
                  return u.HasPrimaryPersonIdElement() ? !0 : ($("#modalInformRtddRequired").modal("show"), !1);
              }),
              (this.UpdateForm = function () {
                  var n = [],
                      t;
                  u.FormElements().forEach(function (t) {
                      var i = [];
                      t.FormElementAttributes().forEach(function (n) {
                          n.ImageSource(null);
                          n.AttributeType() !== FormElementAttributeTypes.PrimaryPersonIdHelpText && (n.Value() === undefined || n.Value() === null || n.Value() === "") && i.push(n);
                      });
                      i.forEach(function (n) {
                          t.FormElementAttributes.remove(n);
                      });
                      t.ElementType() !== FormElementTypes.Image || t.FormElementAttributes()[0] || n.push(t);
                  });
                  n.forEach(function (n) {
                      n.Id !== 0 && u.DeletedFormElements.push(n.Id);
                      u.FormElements.remove(n);
                  });
                  t = ko.toJSON(u);
                  $.ajax({
                      url: "/FormManagement/FormBuilder",
                      type: "POST",
                      contentType: "application/json; charset=utf-8",
                      data: t,
                      success: function (n) {
                          n && n.error
                              ? ($("#divError").text(n.message),
                                $("#divError").removeClass("hidden"),
                                $("#divError").fadeTo(6e3, 2e3, function () {
                                    $("#divError").slideUp(1e3);
                                }),
                                u.Saving(!1))
                              : location.reload();
                      },
                      error: function (n, t) {
                          if (t === "error") {
                              var i = n.responseJSON.message;
                              i.includes("length of the string exceeds") && (i = "The form data exceeds the maximum size allowed. Please resize any images to smaller sizes or convert JPG images to PNG.");
                              $("#divError").text("Error during save: " + i);
                              $("#divError").removeClass("hidden");
                              u.Saving(!1);
                          }
                      },
                  });
              }),
              (this.CopyImageAttribute = function (n, t) {
                  var i;
                  n &&
                      ((i = new FormData()),
                      i.append("token", n),
                      $.ajax({
                          url: "/FormManagement/CopyImage",
                          type: "POST",
                          data: i,
                          async: !1,
                          processData: !1,
                          contentType: !1,
                          success: function (n) {
                              n && n.array && n.token ? (t.ImageSource(n.array), t.Value(n.token), t.ValidationErrors("")) : n && n.error && t.ValidationErrors(n.message);
                          },
                      }));
              }),
              (this.FormId = n().FormId),
              this.FormTitle(n().FormTitle),
              (this.FormElements = ko.observableArray()),
              (this.FormTerms = n().FormTerms()),
              (this.CollectPayments = n().CollectPayments),
              (this.FormDefSalesTaxes = n().SalesTaxes()),
              (this.HasSalesTax = this.FormDefSalesTaxes.length > 0),
              (this.InstitutionInfo = t),
              this.PrimaryPersonLabel(t.PrimaryPersonLabel),
              (this.CallRtddEnabled = n().CallRtdd),
              (this.HasMultipleTermsOrAccounts = this.FormTerms && this.FormTerms.length > 1),
              !this.HasMultipleTermsOrAccounts)
          )
              for (f = 0, e = this.FormTerms; f < e.length; f++) if (((o = e[f]), (this.HasMultipleTermsOrAccounts = o.FormAccounts().length > 1), this.HasMultipleTermsOrAccounts)) break;
          n()
              .FormElements()
              .sort(function (n, t) {
                  return n.DisplayOrder() - t.DisplayOrder();
              });
          n()
              .FormElements()
              .forEach(function (n) {
                  u.FormElements.push(n);
              });
          this.AllowPrimaryPersonIdSelect = this.CallRtddEnabled && this.HasPrimaryPersonIdElement() ? !1 : !0;
          this.DeletedFormElementOptions = r;
          this.DeletedFormElements = i;
          this.Activate = !1;
          this.Saving(!1);
          this.InMovingState = ko.computed(function () {
              return u.CurrentMovingElement() != null;
          });
          this.QuickMoveDisplay = ko.computed(function () {
              var t = u.CurrentMovingElement(),
                  n = "Click to move here";
              return t !== null && t.ElementType() !== FormElementTypes.Paragraph && t.ElementType() !== FormElementTypes.Image && (n = 'Click to move "' + t.Text() + '" here'), n.length > 50 && (n = n.substring(0, 50) + '" ...'), n;
          });
          this.FormTitle.extend({ required: { message: "Form Title is required" } });
          this.QuickMoveDisplay = ko.computed(function () {
              var t = u.CurrentMovingElement(),
                  n = "Click to move here";
              return t !== null && t.ElementType() !== FormElementTypes.Paragraph && t.ElementType() !== FormElementTypes.Image && (n = 'Click to move "' + t.Text() + '" here'), n.length > 50 && (n = n.substring(0, 50) + '" ...'), n;
          });
          this.PrimaryPersonIdSpecialFormat = ko
              .pureComputed({
                  owner: this,
                  read: function () {
                      return FormElementCustomerData.GetPrimaryPersonIdAttributeValue(u.PrimaryPersonIdElement, FormElementAttributeTypes.PrimaryPersonIdSpecialFormat);
                  },
                  write: function (n) {
                      FormElementCustomerData.SetPrimaryPersonIdAttributeValue(u.PrimaryPersonIdElement, FormElementAttributeTypes.PrimaryPersonIdSpecialFormat, n);
                  },
              })
              .extend({
                  required: {
                      message: "Special Format is required",
                      onlyIf: function () {
                          return u.HasPrimaryPersonIdElement();
                      },
                  },
              });
          this.HasPrimaryPersonIdCharLimitFormat = ko.computed(function () {
              return u.PrimaryPersonIdSpecialFormat() === PrimaryPersonIdSpecialFormatTypes.CharacterLimit.toString();
          });
          this.HasPrimaryPersonIdDefinedFormat = ko.computed(function () {
              return u.PrimaryPersonIdSpecialFormat() === PrimaryPersonIdSpecialFormatTypes.DefinedFormat.toString();
          });
          this.PrimaryPersonIdMinChars = ko
              .pureComputed({
                  owner: this,
                  read: function () {
                      var n = FormElementCustomerData.GetPrimaryPersonIdAttributeValue(u.PrimaryPersonIdElement, FormElementAttributeTypes.PrimaryPersonIdMinCharacters);
                      return n !== "" ? n : "0";
                  },
                  write: function (n) {
                      FormElementCustomerData.SetPrimaryPersonIdAttributeValue(u.PrimaryPersonIdElement, FormElementAttributeTypes.PrimaryPersonIdMinCharacters, n);
                  },
              })
              .extend({
                  required: {
                      message: "Mininimum Character Limit is required",
                      onlyIf: function () {
                          return u.HasPrimaryPersonIdElement() && u.HasPrimaryPersonIdCharLimitFormat();
                      },
                  },
                  notEqual: {
                      message: "Mininimum Character Limit must be greater than zero",
                      params: "0",
                      onlyIf: function () {
                          return u.HasPrimaryPersonIdElement() && u.HasPrimaryPersonIdCharLimitFormat();
                      },
                  },
              });
          this.PrimaryPersonIdMaxChars = ko
              .pureComputed({
                  owner: this,
                  read: function () {
                      var n = FormElementCustomerData.GetPrimaryPersonIdAttributeValue(u.PrimaryPersonIdElement, FormElementAttributeTypes.PrimaryPersonIdMaxCharacters);
                      return n !== "" ? n : "0";
                  },
                  write: function (n) {
                      FormElementCustomerData.SetPrimaryPersonIdAttributeValue(u.PrimaryPersonIdElement, FormElementAttributeTypes.PrimaryPersonIdMaxCharacters, n);
                  },
              })
              .extend({
                  required: {
                      message: "Maximum Character Limit is required",
                      onlyIf: function () {
                          return u.HasPrimaryPersonIdElement() && u.HasPrimaryPersonIdCharLimitFormat();
                      },
                  },
                  notEqual: {
                      message: "Maximum Character Limit must be greater than zero",
                      params: "0",
                      onlyIf: function () {
                          return u.HasPrimaryPersonIdElement() && u.HasPrimaryPersonIdCharLimitFormat();
                      },
                  },
              });
          this.PrimaryPersonIdCharacterType = ko
              .pureComputed({
                  owner: this,
                  read: function () {
                      return FormElementCustomerData.GetPrimaryPersonIdAttributeValue(u.PrimaryPersonIdElement, FormElementAttributeTypes.PrimaryPersonIdCharacterType);
                  },
                  write: function (n) {
                      FormElementCustomerData.SetPrimaryPersonIdAttributeValue(u.PrimaryPersonIdElement, FormElementAttributeTypes.PrimaryPersonIdCharacterType, n);
                  },
              })
              .extend({
                  required: {
                      message: "Format is required",
                      onlyIf: function () {
                          return u.HasPrimaryPersonIdElement() && u.HasPrimaryPersonIdCharLimitFormat();
                      },
                  },
              });
          this.PrimaryPersonIdRegex = ko
              .pureComputed({
                  owner: this,
                  read: function () {
                      return FormElementCustomerData.GetPrimaryPersonIdAttributeValue(u.PrimaryPersonIdElement, FormElementAttributeTypes.PrimaryPersonIdRegex);
                  },
                  write: function (n) {
                      FormElementCustomerData.SetPrimaryPersonIdAttributeValue(u.PrimaryPersonIdElement, FormElementAttributeTypes.PrimaryPersonIdRegex, n);
                  },
              })
              .extend({
                  required: {
                      message: "Regex Validation is required",
                      onlyIf: function () {
                          return u.HasPrimaryPersonIdElement() && u.HasPrimaryPersonIdDefinedFormat();
                      },
                  },
                  validation: {
                      validator: this.ValidateRegexFormat,
                      message: "The Regex Validation entered is not in the correct format",
                      onlyIf: function () {
                          return u.HasPrimaryPersonIdElement() && u.HasPrimaryPersonIdDefinedFormat();
                      },
                  },
                  maxLength: {
                      params: 200,
                      message: "Regex Validation cannot be more than 200 characters",
                      onlyIf: function () {
                          return u.HasPrimaryPersonIdElement() && u.HasPrimaryPersonIdDefinedFormat();
                      },
                  },
              });
          this.PrimaryPersonIdHelpText = ko
              .pureComputed({
                  owner: this,
                  read: function () {
                      return FormElementCustomerData.GetPrimaryPersonIdAttributeValue(u.PrimaryPersonIdElement, FormElementAttributeTypes.PrimaryPersonIdHelpText);
                  },
                  write: function (n) {
                      FormElementCustomerData.SetPrimaryPersonIdAttributeValue(u.PrimaryPersonIdElement, FormElementAttributeTypes.PrimaryPersonIdHelpText, n);
                  },
              })
              .extend({ maxLength: { params: 200, message: "Help Text cannot be more than 200 characters" } });
          this.HasCustomerDataElement() &&
              ((s = ko.utils.arrayFirst(this.FormElements(), function (n) {
                  return n.CustomerElementType() === CustomerElementTypes.CustomerLabel;
              })),
              s.Text.subscribe(function (n) {
                  u.PrimaryPersonLabel(n);
              }));
          this.SignatureHelpURL = ko.computed(function () {
              return t.MarketInd === EnterpriseMarketType.HigherEd.valueOf()
                  ? "https://www.nbshubhelp.com/@app/auth/3/login?returnto=/Nelnet_Campus_Commerce/Enterprise/Payment_Forms/Payment_Form_Elements/Nelnet_Campus_Commerce_Payment_Forms_Sample_Verbiage_for_Terms_and_Conditions?utm_source=deeplink%26utm_medium=copy%26utm_campaign=user_shared"
                  : t.MarketInd === EnterpriseMarketType.K12.valueOf()
                  ? "https://www.nbshubhelp.com/@app/auth/3/login?returnto=/FACTS_Management/FACTS_Payment_Forms/Payment_Form_Elements/FACTS_Payment_Forms_Sample_Verbiage_for_Terms_and_Conditions?utm_source=deeplink%26utm_medium=copy%26utm_campaign=user_shared"
                  : null;
          });
          this.InstitutionTermsEdit = ko
              .computed({
                  owner: this,
                  read: function () {
                      var n = FormElementSignature.GetSignatureAttributeValue(u.GetSignatureElement, FormElementAttributeTypes.AdditionalText2);
                      return n != null ? n : "";
                  },
                  write: function (n) {
                      FormElementSignature.SetSignatureAttributeValue(u.GetSignatureElement, FormElementAttributeTypes.AdditionalText2, n);
                  },
              })
              .extend({
                  required: {
                      message: "Institution Terms Text is required.",
                      onlyIf: function () {
                          return u.HasSignatureElement();
                      },
                  },
              });
          this.InstitutionTermsHeaderEdit = ko
              .computed({
                  owner: this,
                  read: function () {
                      var n = FormElementSignature.GetSignatureAttributeValue(u.GetSignatureElement, FormElementAttributeTypes.AdditionalText2Header);
                      return n !== null ? n : "";
                  },
                  write: function (n) {
                      FormElementSignature.SetSignatureAttributeValue(u.GetSignatureElement, FormElementAttributeTypes.AdditionalText2Header, n);
                  },
              })
              .extend({
                  required: {
                      message: "An Institution Terms Header value is required.",
                      onlyIf: function () {
                          return u.HasSignatureElement();
                      },
                  },
              });
      }
      return (
          Object.defineProperty(n.prototype, "GetSignatureElement", {
              get: function () {
                  return ko.utils.arrayFirst(this.FormElements(), function (n) {
                      return n.ElementType() === FormElementTypes.Signature;
                  });
              },
              enumerable: !1,
              configurable: !0,
          }),
          Object.defineProperty(n.prototype, "PrimaryPersonIdElement", {
              get: function () {
                  return ko.utils.arrayFirst(this.FormElements(), function (n) {
                      return n.CustomerElementType() === CustomerElementTypes.PrimaryPersonId;
                  });
              },
              enumerable: !1,
              configurable: !0,
          }),
          n
      );
  })(),
  FormDisplayViewModel = (function () {
      function n(n, t, i, r) {
          var u = this,
              f,
              e;
          r === void 0 && (r = null);
          this.TotalTax = ko.observable(new Money());
          this.GrandTotal = ko.observable(new Money());
          this.CustomerFacingElements = ko.observableArray([]);
          this.ShowErrors = ko.observable(!1);
          this.FormSubmitted = ko.observable(!1);
          this.CustomerSalesTaxes = ko.observableArray([]);
          this.FormTerms = Array();
          this.TermCode = ko.observable(undefined);
          this.AcceptSignature = ko.observable(!1);
          this.SignatureValueEdit = ko.observable(undefined);
          this.ConfirmPrimaryPersonId = function () {
              var n = ko.utils.arrayFirst(u.CustomerFacingElements(), function (n) {
                      return n.CustomerElementType === CustomerElementTypes.PrimaryPersonId;
                  }),
                  t = ko.utils.arrayFirst(u.CustomerFacingElements(), function (n) {
                      return n.CustomerElementType === CustomerElementTypes.ConfirmPrimaryPersonId;
                  });
              return n === undefined || t === undefined ? !0 : n.Value().toLowerCase() === t.Value().toLowerCase();
          };
          this.SubmitForm = function () {
              u.Errors().length > 0 && (u.Errors.showAllMessages(!0), u.ShowErrors(!0), window.scrollTo(0, 0));
          };
          this.CustomerCountryCodeChanged = function () {
              var t = ko.utils.arrayFirst(u.CustomerFacingElements(), function (n) {
                      return n.CustomerElementType === CustomerElementTypes.CustomerPostalCode;
                  }),
                  n;
              t !== null && t.Value("");
              n = ko.utils.arrayFirst(u.CustomerFacingElements(), function (n) {
                  return n.CustomerElementType === CustomerElementTypes.CustomerStateProvince;
              });
              n !== null && n.Value("");
          };
          this.TermCodeChanged = function (n) {
              var t = 0,
                  i = ko.utils.arrayFirst(u.FormTerms, function (t) {
                      return t.TermCode() === n;
                  });
              i && (t = i.Id);
              u.CustomerFacingElements().forEach(function (n) {
                  n.TermChanged(t);
              });
          };
          this.SignatureValueChanged = function (n) {
              var t = ko.utils.arrayFirst(u.CustomerFacingElements(), function (n) {
                  return n.ElementType === FormElementTypes.Signature;
              });
              t.Value(u.BuildSignatureValue(n, u.AcceptSignature()));
          };
          this.AcceptValueChanged = function (n) {
              var t = ko.utils.arrayFirst(u.CustomerFacingElements(), function (n) {
                      return n.ElementType === FormElementTypes.Signature;
                  }),
                  i;
              u.ShowSignatureNameField() ? t.Value(u.BuildSignatureValue(u.SignatureValueEdit().toString(), n)) : n ? ((i = new Date().toLocaleString(u.InstCultureInfoCode)), t.Value(i)) : t.Value(null);
          };
          this.BuildSignatureValue = function (n, t) {
              if (t && n !== null && n.length > 1) {
                  var i = new Date().toLocaleString(u.InstCultureInfoCode);
                  return n + " @ " + i;
              }
              return null;
          };
          this.DisplayTermSelect = function () {
              return u.FormTerms && u.FormTerms.length > 1;
          };
          this.Definition = n;
          this.InstCountry = t.CountryCode;
          this.InstCultureInfoCode = t.CultureInfoCode;
          this.AllowSalesTaxInd = t.AllowSalesTaxInd;
          this.AcceptSignature.subscribe(this.AcceptValueChanged);
          this.SignatureValueEdit.subscribe(this.SignatureValueChanged);
          this.FeatureFlag = r;
          this.CustomerFacingElementsAvailableForTerm = ko.computed(function () {
              return ko.utils.arrayFilter(u.CustomerFacingElements(), function (n) {
                  return !n.HiddenForTerm();
              });
          });
          this.Total = ko.computed(function () {
              var r = 0,
                  t = 0,
                  i = 0,
                  f,
                  e,
                  o;
              return (
                  u.CustomerSalesTaxes().forEach(function (n) {
                      n.TaxAccumulator = 0;
                  }),
                  u.CustomerFacingElementsAvailableForTerm().forEach(function (n) {
                      if (((t = 0), n.ElementType === FormElementTypes.Product && n.Value() !== undefined && n.Value() !== null)) {
                          if (+n.Attributes[0].Value === ProductDisplayType.CheckboxCollection)
                              n.Value().forEach(function (i) {
                                  var r = i.Total().Amount();
                                  t += r;
                                  u.CustomerSalesTaxes().forEach(function (t) {
                                      n.HasSalesTaxItem(t.Id) && (t.TaxAccumulator += Money.RoundToEven(r * t.Rate()));
                                  });
                              });
                          else {
                              var i = n.Value().Total().Amount();
                              t += i;
                              u.CustomerSalesTaxes().forEach(function (t) {
                                  n.HasSalesTaxItem(t.Id) && (t.TaxAccumulator += Money.RoundToEven(i * t.Rate()));
                              });
                          }
                          r += t;
                      }
                  }),
                  (u.FormTerms = ko.utils.arrayFilter(n().FormTerms(), function (n) {
                      return n.HideTerm() === !1;
                  })),
                  u.TermCode.extend({
                      required: {
                          message: "Term must be selected",
                          onlyIf: function () {
                              return u.FormTerms && u.FormTerms.length > 0;
                          },
                      },
                  }),
                  (f = new Money()),
                  f.Amount(r),
                  u.CustomerSalesTaxes().forEach(function (n) {
                      var t = new Money();
                      t.Amount(n.TaxAccumulator);
                      n.TotalTax(t);
                      i = i + n.TaxAccumulator;
                  }),
                  (e = new Money()),
                  e.Amount(i),
                  u.TotalTax(e),
                  (o = new Money()),
                  o.Amount(r + i),
                  u.GrandTotal(o),
                  f
              );
          });
          f = new ElementMapperEngine();
          n()
              .FormElements()
              .forEach(function (n) {
                  var r = f.ConvertElementToCustomerElement(n, i, u),
                      t;
                  u.CustomerFacingElements.push(r);
                  r.CustomerElementType === CustomerElementTypes.CustomerLabel && (u.CustomerLabel = r.SectionName !== null ? r.SectionName : "");
                  r.CustomerElementType === CustomerElementTypes.PrimaryPersonId &&
                      ((t = new CustomerFormElement()),
                      (t.SectionName = n.Text()),
                      (t.ElementId = 0),
                      (t.ElementType = n.ElementType()),
                      (t.CustomerElementType = CustomerElementTypes.ConfirmPrimaryPersonId),
                      (t.Required = !0),
                      (t.MaxLength = 100),
                      (t.Value = ko
                          .observable()
                          .extend({
                              required: { params: t.SectionName, message: "Please re-enter {0} to confirm" },
                              validation: { validator: u.ConfirmPrimaryPersonId, params: t.SectionName, message: "{0} values entered do not match" },
                          })),
                      u.CustomerFacingElements.push(t));
                  r.ElementType === FormElementTypes.Signature &&
                      n.FormElementAttributes().forEach(function (t) {
                          switch (t.AttributeType()) {
                              case FormElementAttributeTypes.AdditionalText1:
                                  u.NbsTerms = ko.computed(function () {
                                      return FormElementSignature.GetSignatureAttributeValue(n, FormElementAttributeTypes.AdditionalText1);
                                  });
                                  break;
                              case FormElementAttributeTypes.AdditionalText1Header:
                                  u.NbsTermsHeader = ko.computed(function () {
                                      return FormElementSignature.GetSignatureAttributeValue(n, FormElementAttributeTypes.AdditionalText1Header);
                                  });
                                  break;
                              case FormElementAttributeTypes.AdditionalText2:
                                  u.InstitutionTerms = ko.computed(function () {
                                      return FormElementSignature.GetSignatureAttributeValue(n, FormElementAttributeTypes.AdditionalText2);
                                  });
                                  break;
                              case FormElementAttributeTypes.AdditionalText2Header:
                                  u.InstitutionTermsHeader = ko.computed(function () {
                                      return FormElementSignature.GetSignatureAttributeValue(n, FormElementAttributeTypes.AdditionalText2Header);
                                  });
                          }
                      });
              });
          e = ko.utils.arrayFirst(this.CustomerFacingElements(), function (n) {
              return n.CustomerElementType === CustomerElementTypes.CustomerCountry;
          });
          e !== null && t.CountryCode !== CountryCode.None && e.Value(CountryCode[t.CountryCode]);
          n()
              .SalesTaxes()
              .forEach(function (n) {
                  var t = new CustomerSalesTax(n);
                  u.CustomerSalesTaxes.push(t);
              });
          this.CustomerCountryCode = ko.computed(function () {
              var n = ko.utils.arrayFirst(u.CustomerFacingElements(), function (n) {
                  return n.CustomerElementType === CustomerElementTypes.CustomerCountry;
              });
              return n !== null ? n.Value() : null;
          });
          this.IsCustomerCountryUsa = ko.computed(function () {
              return u.CustomerCountryCode() === "USA";
          });
          this.CustomerCountryCode.subscribe(this.CustomerCountryCodeChanged);
          i && f.PrepopulateCustomerFacingElements(this.CustomerFacingElements(), i);
          this.TermCode.subscribe(this.TermCodeChanged);
          this.FormTerms && this.FormTerms.length == 1 ? this.TermCode(this.FormTerms[0].TermCode()) : this.FormTerms && this.TermCodeChanged("0");
          this.ShowSignatureNameField = ko.computed(function () {
              var n = ko.utils.arrayFirst(u.CustomerFacingElements(), function (n) {
                  return n.ElementType === FormElementTypes.Signature;
              });
              return n !== null
                  ? ko.utils.arrayFirst(n.Attributes, function (n) {
                        return n.Value.toString() === SignatureTypeEnum.ConsumerEnteredName.toString();
                    }) !== null
                  : !1;
          });
      }
      return n;
  })(),
  PayitEditorViewModel = (function () {
      function n(n, t, i) {
          this.DeletedElements = ko.observableArray([]);
          this.DeletedOptions = ko.observableArray([]);
          var r = new ElementMapperEngine(),
              u = r.HydrateDefinition(n, this.DeletedElements, this.DeletedOptions);
          this.FeatureFlag = ko.observable(i);
          this.FormDefinition = ko.observable(u);
          this.FormBuilder = new FormBuilderViewModel(this.FormDefinition, t, this.DeletedElements, this.DeletedOptions);
          this.FormDisplay = new FormDisplayViewModel(this.FormDefinition, t, null, this.FeatureFlag);
      }
      return n;
  })(),
  __extends =
      (this && this.__extends) ||
      (function () {
          var n = function (t, i) {
              return (
                  (n =
                      Object.setPrototypeOf ||
                      ({ __proto__: [] } instanceof Array &&
                          function (n, t) {
                              n.__proto__ = t;
                          }) ||
                      function (n, t) {
                          for (var i in t) Object.prototype.hasOwnProperty.call(t, i) && (n[i] = t[i]);
                      }),
                  n(t, i)
              );
          };
          return function (t, i) {
              function r() {
                  this.constructor = t;
              }
              n(t, i);
              t.prototype = i === null ? Object.create(i) : ((r.prototype = i.prototype), new r());
          };
      })(),
  CustomerFormViewModel = (function (n) {
      function t(t, i, r, u) {
          var f = n.call(this, t, i, r, u) || this;
          return (
              (f.PreviewMode = !1),
              (f.PrepopulateRequestId = ""),
              (f.SubmitForm = function () {
                  var n, t;
                  if ((f.FormSubmitted(!0), $("#divError").addClass("hidden"), f.Errors().length > 0)) return f.Errors.showAllMessages(!0), f.ShowErrors(!0), f.FormSubmitted(!1), window.scrollTo(0, 0), !1;
                  if (f.PreviewMode) return f.FormSubmitted(!1), !1;
                  n = [];
                  f.CustomerFacingElementsAvailableForTerm().forEach(function (t) {
                      var r, u, i, e;
                      switch (t.CustomerElementType) {
                          case CustomerElementTypes.DaytimePhone:
                          case CustomerElementTypes.EveningPhone:
                          case CustomerElementTypes.MobilePhone:
                              r = document.querySelector("input[name='" + t.SectionName + "']");
                              f.FeatureFlag().enableInternationalPhoneValidation ? ((u = window.intlTelInputGlobals.getInstance(r)), (t.Value = ko.observable(u.getNumber(intlTelInputUtils.numberFormat.E164)))) : (t.Value = r.value);
                      }
                      if (t.ElementType !== FormElementTypes.Paragraph && t.ElementType !== FormElementTypes.Heading && t.ElementType !== FormElementTypes.Image) {
                          i = new CustomerFormResult();
                          i.FormElementId = t.ElementId;
                          switch (t.ElementType) {
                              case FormElementTypes.DropdownList:
                              case FormElementTypes.RadioButtons:
                                  i.FormElementOptionId = t.Value();
                                  n.push(i);
                                  break;
                              case FormElementTypes.Product:
                                  t.Value() !== undefined &&
                                      t.Value() !== null &&
                                      (+t.Attributes[0].Value === ProductDisplayType.CheckboxCollection
                                          ? t.Value().forEach(function (i) {
                                                var r = new CustomerFormResult();
                                                r.FormElementId = t.ElementId;
                                                r.FormElementOptionId = i.Value;
                                                r.Value = i.Quantity();
                                                i.Price !== undefined && i.Price !== null && (r.UnitPrice = i.Price.Amount());
                                                n.push(r);
                                            })
                                          : t.Value().Value > 0 &&
                                            ((i.FormElementOptionId = t.Value().Value), (i.Value = t.Value().Quantity()), t.Value().Price !== undefined && t.Value().Price !== null && (i.UnitPrice = t.Value().Price.Amount()), n.push(i)));
                                  break;
                              case FormElementTypes.Checkboxes:
                                  t.Value().forEach(function (i) {
                                      var r = new CustomerFormResult();
                                      r.FormElementId = t.ElementId;
                                      r.FormElementOptionId = i;
                                      n.push(r);
                                  });
                                  break;
                              case FormElementTypes.Date:
                                  t.Value() && ((e = t.Value().toLocaleDateString(f.InstCultureInfoCode)), (i.Value = e), n.push(i));
                                  break;
                              default:
                                  i.Value = t.Value;
                                  n.push(i);
                          }
                      }
                  });
                  t = { FormResults: n, FormId: f.Definition().FormId, TermCode: f.TermCode(), PrepopulateRequestId: f.PrepopulateRequestId };
                  $.ajax({
                      url: "/form",
                      type: "POST",
                      contentType: "application/json; charset=utf-8",
                      data: ko.toJSON(t),
                      success: function (n) {
                          n.Successful
                              ? (window.location.href = n.SignOnUrl)
                              : (f.FormSubmitted(!1), n.ErrorRedirectUrl ? (window.location.href = n.ErrorRedirectUrl) : ($("#divError").text(n.Message), $("#divError").removeClass("hidden")));
                      },
                  });
              }),
              (f.FeatureFlag = u),
              r && (f.PrepopulateRequestId = r.RequestId),
              f
          );
      }
      return __extends(t, n), t;
  })(FormDisplayViewModel);
