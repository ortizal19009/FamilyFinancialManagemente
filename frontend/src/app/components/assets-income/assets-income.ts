import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';

@Component({
  selector: 'app-assets-income',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './assets-income.html',
  styleUrl: './assets-income.scss'
})
export class AssetsIncomeComponent implements OnInit {
  private apiService = inject(ApiService);

  assets: any[] = [];
  incomeRecords: any[] = [];
  familyMembers: any[] = [];

  newAsset = {
    name: '',
    value: 0,
    owner: '',
    description: '',
    purchase_date: new Date().toISOString().split('T')[0]
  };

  newIncome = {
    amount: 0,
    source: '',
    income_date: new Date().toISOString().split('T')[0],
    description: ''
  };

  loadingAsset = false;
  loadingIncome = false;
  successMsg = '';
  errorMsg = '';

  ngOnInit() {
    this.loadData();
  }

  loadData() {
    this.apiService.getAssets().subscribe(data => this.assets = data);
    this.apiService.getIncome().subscribe(data => this.incomeRecords = data);
    this.apiService.getFamilyMembers().subscribe(data => this.familyMembers = data);
  }

  onCreateAsset() {
    this.loadingAsset = true;
    this.apiService.createAsset(this.newAsset).subscribe({
      next: () => {
        this.successMsg = 'Bien registrado correctamente';
        this.resetAssetForm();
        this.loadData();
        this.loadingAsset = false;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: () => {
        this.errorMsg = 'Error al registrar el bien';
        this.loadingAsset = false;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  onCreateIncome() {
    this.loadingIncome = true;
    this.apiService.createIncome(this.newIncome).subscribe({
      next: () => {
        this.successMsg = 'Ingreso registrado correctamente';
        this.resetIncomeForm();
        this.loadData();
        this.loadingIncome = false;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: () => {
        this.errorMsg = 'Error al registrar el ingreso';
        this.loadingIncome = false;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  resetAssetForm() {
    this.newAsset = {
      name: '',
      value: 0,
      owner: '',
      description: '',
      purchase_date: new Date().toISOString().split('T')[0]
    };
  }

  resetIncomeForm() {
    this.newIncome = {
      amount: 0,
      source: '',
      income_date: new Date().toISOString().split('T')[0],
      description: ''
    };
  }

  getTotalAssetsValue(): number {
    return this.assets.reduce((acc, curr) => acc + curr.value, 0);
  }
}
